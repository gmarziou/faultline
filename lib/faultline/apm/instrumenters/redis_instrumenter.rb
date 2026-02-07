# frozen_string_literal: true

module Faultline
  module Apm
    module Instrumenters
      class RedisInstrumenter
        class << self
          def start!
            return if @subscriber

            # Redis 4.6+ uses ActiveSupport::Notifications
            @subscriber = ActiveSupport::Notifications.subscribe("command.redis") do |*args|
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
            commands = payload[:commands] || [[payload[:command]]]
            command_name = commands.first&.first&.to_s&.upcase || "UNKNOWN"

            # Build description from command
            args = commands.first&.drop(1) || []
            key = args.first.to_s

            description = if key.present?
                            "#{command_name} #{key.truncate(100)}"
                          else
                            command_name
                          end

            SpanCollector.record_span(
              type: :redis,
              description: description,
              start_time: event.time.to_f,
              duration_ms: event.duration,
              metadata: {
                command: command_name,
                key: key.presence,
                database: payload[:database]
              }.compact
            )
          end
        end
      end
    end
  end
end
