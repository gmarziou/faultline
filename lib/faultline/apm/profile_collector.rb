# frozen_string_literal: true

module Faultline
  module Apm
    class ProfileCollector
      THREAD_KEY = :faultline_apm_profiling

      class << self
        def stackprof_available?
          return @stackprof_available if defined?(@stackprof_available)

          @stackprof_available = begin
            require "stackprof"
            true
          rescue LoadError
            false
          end
        end

        def should_profile?
          config = Faultline.configuration
          stackprof_available? &&
            config.apm_enable_profiling &&
            rand < config.apm_profile_sample_rate
        end

        def start_profiling
          return false unless should_profile?

          config = Faultline.configuration
          Thread.current[THREAD_KEY] = true

          StackProf.start(
            mode: config.apm_profile_mode,
            interval: config.apm_profile_interval,
            raw: true
          )

          true
        end

        def profiling?
          Thread.current[THREAD_KEY] == true
        end

        def stop_profiling
          return nil unless profiling?

          Thread.current[THREAD_KEY] = false
          StackProf.stop
          StackProf.results
        end

        def clear
          Thread.current[THREAD_KEY] = nil
        end

        def encode_profile(results)
          return nil unless results

          Base64.encode64(Marshal.dump(results))
        end
      end
    end
  end
end
