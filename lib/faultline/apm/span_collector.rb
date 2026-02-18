# frozen_string_literal: true

module Faultline
  module Apm
    # Collects APM spans for the current request using Thread-local storage.
    #
    # Thread-safety: all state is stored in Thread.current, so each thread
    # (and Fiber in Fiber-based servers like Falcon) has its own isolated
    # span list. This means SpanCollector is safe under threaded servers
    # (Puma) with no locking required. However, spans recorded on a
    # background thread spawned during a request will NOT be captured,
    # since they run on a different Thread.current.
    class SpanCollector
      THREAD_KEY_SPANS = :faultline_apm_spans
      THREAD_KEY_START_TIME = :faultline_apm_request_start
      THREAD_KEY_SPAN_WARNED = :faultline_apm_span_warned

      # Large negative offset (ms) that suggests a clock anomaly worth logging.
      ANOMALY_THRESHOLD_MS = -100

      # Maximum spans stored per request. Requests that exceed this limit (e.g.
      # N+1 loops) have their remaining spans silently dropped after a one-time
      # warning, preventing OOM pressure and column size limit violations.
      MAX_SPANS = 500

      class << self
        def start_request
          Thread.current[THREAD_KEY_SPANS] = []
          Thread.current[THREAD_KEY_START_TIME] = monotonic_now
        end

        def request_start_time
          Thread.current[THREAD_KEY_START_TIME]
        end

        def record_span(type:, description:, duration_ms:, metadata: {})
          return unless Thread.current[THREAD_KEY_SPANS]

          request_start = Thread.current[THREAD_KEY_START_TIME]
          return unless request_start

          # Calculate offset using monotonic clock: callback runs right after event ends,
          # so event_start = now - duration
          now = monotonic_now
          event_start = now - (duration_ms / 1000.0)
          offset_ms = ((event_start - request_start) * 1000).round(2)

          if offset_ms < ANOMALY_THRESHOLD_MS
            Rails.logger.warn(
              "[Faultline] Span timing anomaly: #{type} '#{description}' has offset " \
              "#{offset_ms.round}ms (duration=#{duration_ms.round(1)}ms). " \
              "Clamping to 0."
            )
          end

          offset_ms = [offset_ms, 0].max

          spans = Thread.current[THREAD_KEY_SPANS]
          if spans.length >= MAX_SPANS
            unless Thread.current[THREAD_KEY_SPAN_WARNED]
              Rails.logger.warn(
                "[Faultline] Span limit (#{MAX_SPANS}) reached for this request. " \
                "Further spans will be dropped."
              )
              Thread.current[THREAD_KEY_SPAN_WARNED] = true
            end
            return
          end

          spans << {
            type: type.to_s,
            description: description,
            start_offset_ms: offset_ms,
            duration_ms: duration_ms.round(2),
            metadata: metadata
          }
        end

        def monotonic_now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        def collect_spans
          spans = Thread.current[THREAD_KEY_SPANS] || []
          clear
          spans
        end

        def clear
          Thread.current[THREAD_KEY_SPANS] = nil
          Thread.current[THREAD_KEY_START_TIME] = nil
          Thread.current[THREAD_KEY_SPAN_WARNED] = nil
        end

        def active?
          Thread.current[THREAD_KEY_SPANS].is_a?(Array)
        end
      end
    end
  end
end
