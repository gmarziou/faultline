# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::RequestTrace, type: :model do
  describe "scopes" do
    describe ".recent" do
      it "orders by created_at descending" do
        old = create(:request_trace, created_at: 2.hours.ago)
        recent = create(:request_trace, created_at: 1.minute.ago)

        expect(described_class.recent.first).to eq(recent)
        expect(described_class.recent.last).to eq(old)
      end
    end

    describe ".since" do
      it "returns traces since the given time" do
        old = create(:request_trace, created_at: 2.days.ago)
        recent = create(:request_trace, created_at: 1.hour.ago)

        result = described_class.since(1.day.ago)

        expect(result).to include(recent)
        expect(result).not_to include(old)
      end
    end

    describe ".for_endpoint" do
      it "filters by endpoint" do
        users = create(:request_trace, endpoint: "UsersController#index")
        posts = create(:request_trace, endpoint: "PostsController#index")

        result = described_class.for_endpoint("UsersController#index")

        expect(result).to include(users)
        expect(result).not_to include(posts)
      end
    end
  end

  describe ".slowest_endpoints" do
    it "returns endpoints ordered by average duration descending" do
      3.times { create(:request_trace, endpoint: "FastController#index", duration_ms: 50) }
      3.times { create(:request_trace, endpoint: "SlowController#index", duration_ms: 500) }

      result = described_class.slowest_endpoints(since: 1.day.ago, limit: 10)

      expect(result.first.endpoint).to eq("SlowController#index")
      expect(result.first.avg_duration.to_f).to be > result.last.avg_duration.to_f
    end

    it "includes request count" do
      5.times { create(:request_trace, endpoint: "UsersController#index") }

      result = described_class.slowest_endpoints(since: 1.day.ago)
      endpoint_result = result.find { |r| r.endpoint == "UsersController#index" }

      expect(endpoint_result.request_count).to eq(5)
    end

    it "includes error count" do
      create(:request_trace, endpoint: "UsersController#index", status: 200)
      create(:request_trace, endpoint: "UsersController#index", status: 500)
      create(:request_trace, endpoint: "UsersController#index", status: 503)

      result = described_class.slowest_endpoints(since: 1.day.ago)
      endpoint_result = result.find { |r| r.endpoint == "UsersController#index" }

      expect(endpoint_result.error_count).to eq(2)
    end

    it "respects the since parameter" do
      create(:request_trace, endpoint: "OldController#index", created_at: 2.days.ago)
      create(:request_trace, endpoint: "RecentController#index", created_at: 1.hour.ago)

      result = described_class.slowest_endpoints(since: 1.day.ago)
      endpoints = result.map(&:endpoint)

      expect(endpoints).to include("RecentController#index")
      expect(endpoints).not_to include("OldController#index")
    end

    it "respects the limit parameter" do
      5.times { |i| create(:request_trace, endpoint: "Controller#{i}#index") }

      result = described_class.slowest_endpoints(since: 1.day.ago, limit: 3)

      expect(result.to_a.size).to eq(3)
    end
  end

  describe ".response_time_series" do
    it "returns bucketed time series data" do
      create(:request_trace, duration_ms: 100, created_at: 1.hour.ago)
      create(:request_trace, duration_ms: 200, created_at: 1.hour.ago)

      result = described_class.response_time_series(period: "24h")

      expect(result).to be_an(Array)
      expect(result.first).to include(:bucket, :avg, :max, :min, :count)
    end

    it "calculates averages correctly" do
      create(:request_trace, duration_ms: 100, created_at: 30.minutes.ago)
      create(:request_trace, duration_ms: 200, created_at: 30.minutes.ago)

      result = described_class.response_time_series(period: "1h")

      # Should have avg of 150ms
      bucket = result.first
      expect(bucket[:avg]).to eq(150.0)
      expect(bucket[:min]).to eq(100.0)
      expect(bucket[:max]).to eq(200.0)
      expect(bucket[:count]).to eq(2)
    end

    it "filters by endpoint when provided" do
      create(:request_trace, endpoint: "UsersController#index", duration_ms: 100, created_at: 30.minutes.ago)
      create(:request_trace, endpoint: "PostsController#index", duration_ms: 500, created_at: 30.minutes.ago)

      result = described_class.response_time_series(period: "1h", endpoint: "UsersController#index")

      bucket = result.first
      expect(bucket[:avg]).to eq(100.0)
      expect(bucket[:count]).to eq(1)
    end
  end

  describe ".throughput_series" do
    it "returns request counts per time bucket" do
      3.times { create(:request_trace, created_at: 1.hour.ago) }
      2.times { create(:request_trace, created_at: 2.hours.ago) }

      result = described_class.throughput_series(period: "24h")

      expect(result).to be_a(Hash)
      expect(result.values.sum).to eq(5)
    end
  end

  describe ".summary_stats" do
    before do
      create(:request_trace, duration_ms: 100, db_runtime_ms: 10, db_query_count: 5, status: 200)
      create(:request_trace, duration_ms: 200, db_runtime_ms: 20, db_query_count: 10, status: 200)
      create(:request_trace, duration_ms: 300, db_runtime_ms: 30, db_query_count: 15, status: 500)
    end

    it "returns total requests count" do
      stats = described_class.summary_stats(since: 1.day.ago)
      expect(stats[:total_requests]).to eq(3)
    end

    it "returns average duration" do
      stats = described_class.summary_stats(since: 1.day.ago)
      expect(stats[:avg_duration]).to eq(200.0)
    end

    it "returns average db runtime" do
      stats = described_class.summary_stats(since: 1.day.ago)
      expect(stats[:avg_db_runtime]).to eq(20.0)
    end

    it "returns average query count" do
      stats = described_class.summary_stats(since: 1.day.ago)
      expect(stats[:avg_query_count]).to eq(10.0)
    end

    it "returns error count" do
      stats = described_class.summary_stats(since: 1.day.ago)
      expect(stats[:error_count]).to eq(1)
    end

    it "returns p95 duration" do
      stats = described_class.summary_stats(since: 1.day.ago)
      expect(stats[:p95_duration]).to be_a(Numeric)
    end

    it "handles empty dataset" do
      Faultline::RequestTrace.delete_all
      stats = described_class.summary_stats(since: 1.day.ago)

      expect(stats[:total_requests]).to eq(0)
      expect(stats[:avg_duration]).to eq(0)
      expect(stats[:error_count]).to eq(0)
    end
  end

  describe ".cleanup!" do
    it "deletes traces older than retention period" do
      old = create(:request_trace, created_at: 35.days.ago)
      recent = create(:request_trace, created_at: 1.day.ago)

      allow(Faultline.configuration).to receive(:apm_retention_days).and_return(30)

      deleted_count = described_class.cleanup!

      expect(deleted_count).to eq(1)
      expect(described_class.find_by(id: old.id)).to be_nil
      expect(described_class.find_by(id: recent.id)).to be_present
    end

    it "accepts custom before parameter" do
      trace1 = create(:request_trace, created_at: 10.days.ago)
      trace2 = create(:request_trace, created_at: 3.days.ago)

      described_class.cleanup!(before: 5.days.ago)

      expect(described_class.find_by(id: trace1.id)).to be_nil
      expect(described_class.find_by(id: trace2.id)).to be_present
    end
  end

  describe ".table_exists_for_apm?" do
    it "returns true when table exists" do
      expect(described_class.table_exists_for_apm?).to be true
    end
  end

  describe "PERIODS constant" do
    it "defines expected periods" do
      expect(described_class::PERIODS.keys).to contain_exactly("1h", "6h", "24h", "7d", "30d")
    end

    it "includes duration and granularity for each period" do
      described_class::PERIODS.each do |_key, config|
        expect(config).to have_key(:duration)
        expect(config).to have_key(:granularity)
      end
    end
  end
end
