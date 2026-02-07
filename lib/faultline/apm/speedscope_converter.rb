# frozen_string_literal: true

module Faultline
  module Apm
    class SpeedscopeConverter
      # Converts stackprof format to speedscope JSON schema
      # https://www.speedscope.app/file-format-spec.json
      class << self
        def convert(stackprof_data)
          return empty_profile unless stackprof_data

          frames = build_frames(stackprof_data)
          samples, weights = build_samples(stackprof_data, frames)

          {
            "$schema": "https://www.speedscope.app/file-format-spec.json",
            shared: {
              frames: frames.values.map { |f| { name: f[:name], file: f[:file], line: f[:line] } }
            },
            profiles: [
              {
                type: "sampled",
                name: "CPU Profile",
                unit: "microseconds",
                startValue: 0,
                endValue: stackprof_data[:samples] * (stackprof_data[:interval] || 1000),
                samples: samples,
                weights: weights
              }
            ],
            name: "Faultline Profile",
            exporter: "Faultline APM"
          }
        end

        private

        def empty_profile
          {
            "$schema": "https://www.speedscope.app/file-format-spec.json",
            shared: { frames: [] },
            profiles: [],
            name: "Empty Profile",
            exporter: "Faultline APM"
          }
        end

        def build_frames(data)
          frames = {}
          frame_index = 0

          data[:frames]&.each do |frame_id, frame_data|
            name = frame_data[:name] || "unknown"
            file = frame_data[:file]
            line = frame_data[:line]

            frames[frame_id] = {
              index: frame_index,
              name: name,
              file: file,
              line: line
            }
            frame_index += 1
          end

          frames
        end

        def build_samples(data, frames)
          samples = []
          weights = []

          raw_data = data[:raw] || []
          interval = data[:interval] || 1000

          i = 0
          while i < raw_data.length
            stack_length = raw_data[i]
            i += 1

            next unless stack_length&.positive?

            stack = []
            stack_length.times do
              frame_id = raw_data[i]
              i += 1
              frame = frames[frame_id]
              stack << frame[:index] if frame
            end

            count = raw_data[i] || 1
            i += 1

            # Speedscope expects stacks with root at the end
            samples << stack.reverse
            weights << count * interval
          end

          [samples, weights]
        end
      end
    end
  end
end
