# frozen_string_literal: true

require "rails_helper"
require "faultline/apm/profile_collector"

RSpec.describe Faultline::Apm::ProfileCollector do
  after(:each) do
    described_class.clear
  end

  describe ".stackprof_available?" do
    it "returns a boolean" do
      expect([true, false]).to include(described_class.stackprof_available?)
    end
  end

  describe ".should_profile?" do
    before do
      allow(Faultline.configuration).to receive(:apm_enable_profiling).and_return(true)
      allow(Faultline.configuration).to receive(:apm_profile_sample_rate).and_return(1.0)
    end

    it "returns false when stackprof is not available" do
      allow(described_class).to receive(:stackprof_available?).and_return(false)
      expect(described_class.should_profile?).to be false
    end

    it "returns false when profiling is disabled" do
      allow(Faultline.configuration).to receive(:apm_enable_profiling).and_return(false)
      expect(described_class.should_profile?).to be false
    end

    it "respects sample rate" do
      allow(described_class).to receive(:stackprof_available?).and_return(true)
      allow(Faultline.configuration).to receive(:apm_profile_sample_rate).and_return(0.0)

      expect(described_class.should_profile?).to be false
    end
  end

  describe ".profiling?" do
    it "returns false when not profiling" do
      expect(described_class.profiling?).to be false
    end
  end

  describe ".encode_profile" do
    it "returns nil for nil input" do
      expect(described_class.encode_profile(nil)).to be_nil
    end

    it "encodes profile data as base64 marshal" do
      data = { samples: 10, frames: {} }
      encoded = described_class.encode_profile(data)

      decoded = Marshal.load(Base64.decode64(encoded))
      expect(decoded[:samples]).to eq(10)
    end
  end

  describe ".clear" do
    it "resets profiling state" do
      Thread.current[:faultline_apm_profiling] = true
      described_class.clear
      expect(described_class.profiling?).to be false
    end
  end
end
