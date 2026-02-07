# frozen_string_literal: true

require "rails_helper"
require "faultline/apm/speedscope_converter"

RSpec.describe Faultline::Apm::SpeedscopeConverter do
  describe ".convert" do
    it "returns empty profile for nil input" do
      result = described_class.convert(nil)

      expect(result[:"$schema"]).to eq("https://www.speedscope.app/file-format-spec.json")
      expect(result[:profiles]).to eq([])
      expect(result[:name]).to eq("Empty Profile")
    end

    it "converts stackprof data to speedscope format" do
      stackprof_data = {
        mode: :cpu,
        interval: 1000,
        samples: 10,
        frames: {
          1 => { name: "main", file: "app.rb", line: 1 },
          2 => { name: "process", file: "app.rb", line: 10 }
        },
        raw: [2, 1, 2, 5, 1, 2, 3]
      }

      result = described_class.convert(stackprof_data)

      expect(result[:"$schema"]).to eq("https://www.speedscope.app/file-format-spec.json")
      expect(result[:shared][:frames].length).to eq(2)
      expect(result[:profiles].length).to eq(1)
      expect(result[:profiles].first[:type]).to eq("sampled")
      expect(result[:exporter]).to eq("Faultline APM")
    end

    it "includes frame information" do
      stackprof_data = {
        mode: :cpu,
        interval: 1000,
        samples: 1,
        frames: {
          1 => { name: "MyClass#method", file: "/app/models/my_class.rb", line: 42 }
        },
        raw: []
      }

      result = described_class.convert(stackprof_data)
      frame = result[:shared][:frames].first

      expect(frame[:name]).to eq("MyClass#method")
      expect(frame[:file]).to eq("/app/models/my_class.rb")
      expect(frame[:line]).to eq(42)
    end
  end
end
