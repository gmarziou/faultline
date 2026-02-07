# frozen_string_literal: true

module Faultline
  module Apm
    class SpanCollector
      THREAD_KEY_SPANS = :faultline_apm_spans
      THREAD_KEY_START_TIME = :faultline_apm_request_start

      class << self
        def start_request
          Thread.current[THREAD_KEY_SPANS] = []
          Thread.current[THREAD_KEY_START_TIME] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        def request_start_time
          Thread.current[THREAD_KEY_START_TIME]
        end

        def record_span(type:, description:, start_time:, duration_ms:, metadata: {})
          return unless Thread.current[THREAD_KEY_SPANS]

          request_start = Thread.current[THREAD_KEY_START_TIME] || start_time
          offset_ms = ((start_time - request_start) * 1000).round(2)

          Thread.current[THREAD_KEY_SPANS] << {
            type: type.to_s,
            description: description,
            start_offset_ms: offset_ms,
            duration_ms: duration_ms.round(2),
            metadata: metadata
          }
        end

        def collect_spans
          spans = Thread.current[THREAD_KEY_SPANS] || []
          clear
          spans
        end

        def clear
          Thread.current[THREAD_KEY_SPANS] = nil
          Thread.current[THREAD_KEY_START_TIME] = nil
        end

        def active?
          Thread.current[THREAD_KEY_SPANS].is_a?(Array)
        end
      end
    end
  end
end
