# frozen_string_literal: true

module Faultline
  class PerformanceController < ApplicationController
    PER_PAGE = 25
    CACHE_TTL = 1.minute

    ENDPOINTS_SORT_COLUMNS = %w[endpoint avg_duration p95_duration request_count avg_db_runtime avg_query_count error_rate].freeze
    REQUESTS_SORT_COLUMNS = %w[created_at path status duration_ms db_runtime_ms view_runtime_ms db_query_count].freeze

    def index
      @period = params[:period].presence || "24h"
      @since = period_to_time(@period)
      @search = params[:q].to_s.strip
      @sort = params[:sort].presence_in(ENDPOINTS_SORT_COLUMNS) || "request_count"
      @dir = params[:dir] == "asc" ? :asc : :desc
      @page = [(params[:page] || 1).to_i, 1].max

      # Cache stats and chart data (not affected by search/sort/page)
      cache_key = "faultline:v1:perf:index:#{@period}:#{cache_time_bucket}"

      cached = Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        {
          stats: RequestTrace.summary_stats(since: @since),
          response_time_data: RequestTrace.response_time_series(period: @period),
          throughput_data: RequestTrace.throughput_series(period: @period)
        }
      end

      @stats = cached[:stats]
      @response_time_data = cached[:response_time_data]
      @throughput_data = cached[:throughput_data]

      # Endpoints with search, sort, pagination (not cached due to dynamic params)
      endpoints_result = RequestTrace.endpoints_paginated(
        since: @since,
        search: @search,
        sort: @sort,
        dir: @dir,
        page: @page,
        per_page: PER_PAGE
      )

      @endpoints = endpoints_result[:records]
      @total_count = endpoints_result[:total_count]
      @total_pages = endpoints_result[:total_pages]
    end

    def show
      @endpoint = params[:id]
      @period = params[:period].presence || "24h"
      @since = period_to_time(@period)
      @search = params[:q].to_s.strip
      @sort = params[:sort].presence_in(REQUESTS_SORT_COLUMNS) || "created_at"
      @dir = params[:dir] == "asc" ? :asc : :desc
      @page = [(params[:page] || 1).to_i, 1].max

      scope = RequestTrace.for_endpoint(@endpoint).since(@since)

      # Cache stats and chart data for 1 minute
      cache_key = "faultline:v1:perf:show:#{@endpoint}:#{@period}:#{cache_time_bucket}"

      cached = Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        {
          stats: endpoint_stats(scope),
          response_time_data: RequestTrace.response_time_series(period: @period, endpoint: @endpoint)
        }
      end

      @stats = cached[:stats]
      @response_time_data = cached[:response_time_data]

      # Apply search filter
      filtered_scope = scope
      if @search.present?
        filtered_scope = filtered_scope.where("path LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(@search)}%")
      end

      # Pagination with dynamic sort
      @total_count = filtered_scope.count
      @total_pages = [(@total_count.to_f / PER_PAGE).ceil, 1].max
      @page = [[@page, 1].max, @total_pages].min if @total_pages > 0

      @recent_traces = filtered_scope.order(@sort => @dir)
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
