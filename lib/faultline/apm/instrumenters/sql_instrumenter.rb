# frozen_string_literal: true

module Faultline
  module Apm
    module Instrumenters
      class SqlInstrumenter
        class << self
          def start!
            return if @subscriber

            @subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
              event = ActiveSupport::Notifications::Event.new(*args)
              process_event(event)
            end
          end

          def stop!
            ActiveSupport::Notifications.unsubscribe(@subscriber) if @subscriber
            @subscriber = nil
          end

          private

          def process_event(event)
            return unless SpanCollector.active?

            payload = event.payload
            return if payload[:name] == "SCHEMA"
            return if payload[:name]&.start_with?("EXPLAIN")

            sql = payload[:sql].to_s
            return if sql.blank?

            # Truncate long SQL for display
            description = sql.length > 200 ? "#{sql[0, 200]}..." : sql

            SpanCollector.record_span(
              type: :sql,
              description: description,
              start_time: event.time.to_f,
              duration_ms: event.duration,
              metadata: {
                name: payload[:name],
                binds: payload[:type_casted_binds]&.size || 0,
                cached: payload[:cached] || false
              }
            )
          end
        end
      end
    end
  end
end
