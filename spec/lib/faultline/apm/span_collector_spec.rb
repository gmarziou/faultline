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
        duration_ms: 5.0
      )

      expect(described_class.collect_spans).to eq([])
    end

    it "records span when active" do
      described_class.start_request

      described_class.record_span(
        type: :sql,
        description: "SELECT * FROM users",
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
      t0 = 1000.0
      # First call returns request start time, second returns "now" when record_span fires
      allow(described_class).to receive(:monotonic_now).and_return(t0, t0 + 0.010)

      described_class.start_request

      # duration_ms = 1ms  →  event_start = (t0 + 0.010) - 0.001 = t0 + 0.009
      # offset_ms = (t0 + 0.009 - t0) * 1000 = 9.0
      described_class.record_span(type: :sql, description: "test", duration_ms: 1.0)

      spans = described_class.collect_spans
      expect(spans.first[:start_offset_ms]).to eq(9.0)
    end
  end

  describe ".collect_spans" do
    it "returns collected spans and clears state" do
      described_class.start_request
      described_class.record_span(
        type: :sql,
        description: "test",
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

  describe "span cap" do
    it "stops recording after MAX_SPANS spans" do
      described_class.start_request

      (described_class::MAX_SPANS + 10).times do |i|
        described_class.record_span(type: :sql, description: "query #{i}", duration_ms: 1.0)
      end

      spans = described_class.collect_spans
      expect(spans.length).to eq(described_class::MAX_SPANS)
    end

    it "logs a warning exactly once when the cap is hit" do
      described_class.start_request

      expect(Rails.logger).to receive(:warn).once.with(/Span limit/)

      (described_class::MAX_SPANS + 5).times do |i|
        described_class.record_span(type: :sql, description: "query #{i}", duration_ms: 1.0)
      end
    end
  end
end
