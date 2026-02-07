# frozen_string_literal: true

require "rails_helper"
require "faultline/apm/span_collector"

RSpec.describe Faultline::Apm::SpanCollector do
  after(:each) do
    described_class.clear
  end

  describe ".start_request" do
    it "initializes span array" do
      described_class.start_request
      expect(described_class.active?).to be true
    end

    it "stores request start time" do
      described_class.start_request
      expect(described_class.request_start_time).to be_a(Float)
    end
  end

  describe ".record_span" do
    it "does nothing when not active" do
      described_class.record_span(
        type: :sql,
        description: "SELECT * FROM users",
        start_time: Time.now.to_f,
        duration_ms: 5.0
      )

      expect(described_class.collect_spans).to eq([])
    end

    it "records span when active" do
      described_class.start_request
      start_time = described_class.request_start_time + 0.001

      described_class.record_span(
        type: :sql,
        description: "SELECT * FROM users",
        start_time: start_time,
        duration_ms: 5.0,
        metadata: { cached: false }
      )

      spans = described_class.collect_spans
      expect(spans.length).to eq(1)
      expect(spans.first[:type]).to eq("sql")
      expect(spans.first[:description]).to eq("SELECT * FROM users")
      expect(spans.first[:duration_ms]).to eq(5.0)
      expect(spans.first[:metadata][:cached]).to eq(false)
    end

    it "calculates start_offset_ms relative to request start" do
      described_class.start_request
      request_start = described_class.request_start_time

      # Record span 10ms after request start
      described_class.record_span(
        type: :sql,
        description: "test",
        start_time: request_start + 0.010,
        duration_ms: 1.0
      )

      spans = described_class.collect_spans
      expect(spans.first[:start_offset_ms]).to be_within(1).of(10.0)
    end
  end

  describe ".collect_spans" do
    it "returns collected spans and clears state" do
      described_class.start_request
      described_class.record_span(
        type: :sql,
        description: "test",
        start_time: Time.now.to_f,
        duration_ms: 1.0
      )

      spans = described_class.collect_spans
      expect(spans.length).to eq(1)
      expect(described_class.active?).to be false
    end
  end

  describe ".clear" do
    it "resets all state" do
      described_class.start_request
      described_class.clear

      expect(described_class.active?).to be false
      expect(described_class.request_start_time).to be_nil
    end
  end
end
