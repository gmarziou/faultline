# frozen_string_literal: true

module Faultline
  module Apm
    module Instrumenters
      class HttpInstrumenter
        # Net::HTTP instrumentation via prepend
        module NetHttpPatch
          def request(req, body = nil, &block)
            return super unless SpanCollector.active?

            start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            response = nil

            begin
              response = super
            ensure
              end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
              duration_ms = (end_time - start_time) * 1000

              path_only = req.path&.split("?")&.first
              uri = "#{use_ssl? ? 'https' : 'http'}://#{address}:#{port}#{path_only}"
              description = "#{req.method} #{uri}"
              description = "#{description[0, 197]}..." if description.length > 200

              SpanCollector.record_span(
                type: :http,
                description: description,
                duration_ms: duration_ms,
                metadata: {
                  method: req.method,
                  host: address,
                  port: port,
                  path: path_only,
                  status: response&.code&.to_i
                }
              )
            end

            response
          end
        end

        class << self
          def start!
            return if @installed

            Net::HTTP.prepend(NetHttpPatch)
            @installed = true
          end

          def stop!
            # Cannot unprepend, but instrumenter checks SpanCollector.active?
          end
        end
      end
    end
  end
end
