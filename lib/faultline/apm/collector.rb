# frozen_string_literal: true

module Faultline
  module Apm
    class Collector
      THREAD_KEY = :faultline_apm_query_count

      class << self
        def start!
          subscribe_to_sql_notifications
          subscribe_to_action_notifications
        end

        def stop!
          ActiveSupport::Notifications.unsubscribe(@sql_subscriber) if @sql_subscriber
          ActiveSupport::Notifications.unsubscribe(@action_subscriber) if @action_subscriber
          @sql_subscriber = nil
          @action_subscriber = nil
        end

        private

        def subscribe_to_sql_notifications
          @sql_subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
            event = ActiveSupport::Notifications::Event.new(*args)
            next if event.payload[:name] == "SCHEMA"
            next if event.payload[:name]&.start_with?("EXPLAIN")

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

          store_trace(
            endpoint: endpoint,
            http_method: payload[:method] || "GET",
            path: path,
            status: status,
            duration_ms: event.duration&.round(2),
            db_runtime_ms: payload[:db_runtime]&.round(2),
            view_runtime_ms: payload[:view_runtime]&.round(2),
            db_query_count: query_count
          )
        rescue StandardError => e
          Rails.logger.debug { "[Faultline APM] Failed to record trace: #{e.message}" }
        ensure
          Thread.current[THREAD_KEY] = 0
        end

        def should_ignore?(path, config)
          return true if path.nil?

          ignore_paths = config.resolved_apm_ignore_paths
          ignore_paths.any? { |p| path.start_with?(p) }
        end

        def store_trace(attrs)
          return unless RequestTrace.table_exists_for_apm?

          RequestTrace.create!(attrs)
        rescue StandardError => e
          Rails.logger.debug { "[Faultline APM] Failed to store trace: #{e.message}" }
        end
      end
    end
  end
end
