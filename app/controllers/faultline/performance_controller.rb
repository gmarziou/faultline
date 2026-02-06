# frozen_string_literal: true

module Faultline
  class PerformanceController < ApplicationController
    PER_PAGE = 25
    CACHE_TTL = 1.minute

    def index
      @period = params[:period].presence || "24h"
      @since = period_to_time(@period)

      # Cache expensive aggregate queries for 1 minute
      cache_key = "faultline:perf:index:#{@period}:#{cache_time_bucket}"

      cached = Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        {
          stats: RequestTrace.summary_stats(since: @since),
          response_time_data: RequestTrace.response_time_series(period: @period),
          throughput_data: RequestTrace.throughput_series(period: @period),
          slowest_endpoints: RequestTrace.slowest_endpoints(since: @since, limit: 20).to_a
        }
      end

      @stats = cached[:stats]
      @response_time_data = cached[:response_time_data]
      @throughput_data = cached[:throughput_data]
      @slowest_endpoints = cached[:slowest_endpoints]
    end

    def show
      @endpoint = params[:id]
      @period = params[:period].presence || "24h"
      @since = period_to_time(@period)

      scope = RequestTrace.for_endpoint(@endpoint).since(@since)

      # Cache stats and chart data for 1 minute
      cache_key = "faultline:perf:show:#{@endpoint}:#{@period}:#{cache_time_bucket}"

      cached = Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        {
          stats: endpoint_stats(scope),
          response_time_data: RequestTrace.response_time_series(period: @period, endpoint: @endpoint)
        }
      end

      @stats = cached[:stats]
      @response_time_data = cached[:response_time_data]

      # Pagination not cached (changes with page param, relatively fast)
      @page = (params[:page] || 1).to_i
      @total_count = @stats[:total_requests]
      @total_pages = [(@total_count.to_f / PER_PAGE).ceil, 1].max
      @recent_traces = scope.order(duration_ms: :desc)
                            .offset((@page - 1) * PER_PAGE)
                            .limit(PER_PAGE)
    end

    private

    def period_to_time(period)
      config = RequestTrace::PERIODS[period]
      config ? config[:duration].ago : 24.hours.ago
    end

    # Time bucket for cache keys - rounds to nearest minute
    def cache_time_bucket
      Time.current.to_i / 60
    end

    # Single query for endpoint stats
    def endpoint_stats(scope)
      row = scope.pick(
        Arel.sql("COUNT(*)"),
        Arel.sql("AVG(duration_ms)"),
        Arel.sql("AVG(db_runtime_ms)"),
        Arel.sql("AVG(db_query_count)"),
        Arel.sql("SUM(CASE WHEN status >= 500 THEN 1 ELSE 0 END)"),
        Arel.sql("MIN(duration_ms)"),
        Arel.sql("MAX(duration_ms)")
      )

      total, avg_duration, avg_db_runtime, avg_query_count, error_count, min_duration, max_duration = row || Array.new(7, 0)

      {
        total_requests: total || 0,
        avg_duration: avg_duration&.round(1) || 0,
        avg_db_runtime: avg_db_runtime&.round(1) || 0,
        avg_query_count: avg_query_count&.round(1) || 0,
        error_count: error_count || 0,
        min_duration: min_duration&.round(1) || 0,
        max_duration: max_duration&.round(1) || 0
      }
    end
  end
end
