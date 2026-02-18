# frozen_string_literal: true

module Faultline
  module Apm
    class Collector
      THREAD_KEY = :faultline_apm_query_count

      class << self
        def start!
          subscribe_to_start_processing
          subscribe_to_sql_notifications
          subscribe_to_action_notifications
          start_instrumenters
        end

        def stop!
          ActiveSupport::Notifications.unsubscribe(@start_subscriber) if @start_subscriber
          ActiveSupport::Notifications.unsubscribe(@sql_subscriber) if @sql_subscriber
          ActiveSupport::Notifications.unsubscribe(@action_subscriber) if @action_subscriber
          @start_subscriber = nil
          @sql_subscriber = nil
          @action_subscriber = nil
          stop_instrumenters
        end

        private

        def start_instrumenters
          config = Faultline.configuration
          return unless config.apm_capture_spans
          return unless instrumenters_available?

          Instrumenters::SqlInstrumenter.start!
          Instrumenters::ViewInstrumenter.start!
          Instrumenters::HttpInstrumenter.start!
          Instrumenters::RedisInstrumenter.start!
        end

        def stop_instrumenters
          return unless instrumenters_available?

          Instrumenters::SqlInstrumenter.stop!
          Instrumenters::ViewInstrumenter.stop!
          Instrumenters::HttpInstrumenter.stop!
          Instrumenters::RedisInstrumenter.stop!
        end

        def instrumenters_available?
          defined?(Instrumenters::SqlInstrumenter)
        end

        def subscribe_to_start_processing
          @start_subscriber = ActiveSupport::Notifications.subscribe("start_processing.action_controller") do |*args|
            event = ActiveSupport::Notifications::Event.new(*args)
            init_request_tracking(event)
          end
        end

        def init_request_tracking(event)
          config = Faultline.configuration
          return unless config&.enable_apm

          path = event.payload[:path]&.split("?")&.first
          return if should_ignore?(path, config)

          # Initialize span collection if enabled
          if config.apm_capture_spans && defined?(SpanCollector)
            SpanCollector.start_request
          end

          # Start profiling if enabled and sampled
          ProfileCollector.start_profiling if defined?(ProfileCollector)
        end

        def subscribe_to_sql_notifications
          @sql_subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
            event = ActiveSupport::Notifications::Event.new(*args)
            next if event.payload[:name] == "SCHEMA"
            next if event.payload[:name]&.start_with?("EXPLAIN")
            next if faultline_internal_sql?(event.payload[:sql])

            Thread.current[THREAD_KEY] = (Thread.current[THREAD_KEY] || 0) + 1
          end
        end

        def subscribe_to_action_notifications
          @action_subscriber = ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*args|
            event = ActiveSupport::Notifications::Event.new(*args)
            process_action_event(event)
          end
        end

        def process_action_event(event)
          payload = event.payload
          config = Faultline.configuration

          return unless config&.enable_apm

          controller = payload[:controller]
          action = payload[:action]
          endpoint = "#{controller}##{action}"
          path = payload[:path]&.split("?")&.first

          return if should_ignore?(path, config)
          return if config.apm_sample_rate < 1.0 && rand > config.apm_sample_rate

          query_count = Thread.current[THREAD_KEY] || 0
          Thread.current[THREAD_KEY] = 0

          status = payload[:status]
          status = 500 if status.nil? && payload[:exception].present?

          # Collect spans if enabled
          spans = if defined?(SpanCollector) && SpanCollector.active?
                    SpanCollector.collect_spans
                  end

          # Stop profiling and get results
          profile_results = defined?(ProfileCollector) ? ProfileCollector.stop_profiling : nil

          store_trace(
            endpoint: endpoint,
            http_method: payload[:method] || "GET",
            path: path,
            status: status,
            duration_ms: event.duration&.round(2),
            db_runtime_ms: payload[:db_runtime]&.round(2),
            view_runtime_ms: payload[:view_runtime]&.round(2),
            db_query_count: query_count,
            spans: spans,
            profile_results: profile_results
          )
        rescue StandardError => e
          Rails.logger.debug { "[Faultline APM] Failed to record trace: #{e.message}" }
        ensure
          Thread.current[THREAD_KEY] = 0
          SpanCollector.clear if defined?(SpanCollector)
          ProfileCollector.clear if defined?(ProfileCollector)
        end

        def faultline_internal_sql?(sql)
          sql.to_s.match?(/\bfaultline_/i)
        end

        def should_ignore?(path, config)
          return true if path.nil?

          ignore_paths = config.resolved_apm_ignore_paths
          ignore_paths.any? { |p| path.start_with?(p) }
        end

        def store_trace(attrs)
          return unless RequestTrace.table_exists_for_apm?

          spans = attrs.delete(:spans)
          profile_results = attrs.delete(:profile_results)

          # Add spans to trace attributes if present
          attrs[:spans] = spans if spans&.any? && column_exists?(:spans)

          # Set has_profile flag if we have profile data
          attrs[:has_profile] = profile_results.present? if column_exists?(:has_profile)

          trace = RequestTrace.create!(attrs)

          # Store profile separately if present
          if profile_results && profile_table_exists?
            store_profile(trace, profile_results)
          end

          trace
        rescue StandardError => e
          Rails.logger.debug { "[Faultline APM] Failed to store trace: #{e.message}" }
        end

        def store_profile(trace, profile_results)
          return unless defined?(ProfileCollector) && defined?(RequestProfile)

          config = Faultline.configuration

          RequestProfile.create!(
            request_trace: trace,
            profile_data: ProfileCollector.encode_profile(profile_results),
            mode: config.apm_profile_mode.to_s,
            samples: profile_results[:samples] || 0,
            interval_ms: (profile_results[:interval] || 1000) / 1000.0
          )
        rescue StandardError => e
          Rails.logger.debug { "[Faultline APM] Failed to store profile: #{e.message}" }
        end

        def column_exists?(column_name)
          # Rely on ActiveRecord's own column_names cache (reset automatically on
          # schema changes) rather than a process-level class variable that would
          # survive zero-downtime migrations without a server restart.
          RequestTrace.column_names.include?(column_name.to_s)
        rescue StandardError
          false
        end

        def profile_table_exists?
          RequestProfile.table_exists?
        rescue StandardError
          false
        end
      end
    end
  end
end
