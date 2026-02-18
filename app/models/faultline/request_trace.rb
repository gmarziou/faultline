# frozen_string_literal: true

module Faultline
  class RequestTrace < ApplicationRecord
    extend SqlTimeGrouping

    has_one :profile, class_name: "Faultline::RequestProfile", dependent: :destroy

    scope :recent, -> { order(created_at: :desc) }
    scope :since, ->(time) { where("created_at >= ?", time) }
    scope :for_endpoint, ->(endpoint) { where(endpoint: endpoint) }

    def parsed_spans
      return [] unless self.class.column_names.include?("spans")
      return [] if spans.blank?

      spans.is_a?(String) ? JSON.parse(spans) : spans
    rescue JSON::ParserError
      []
    end

    def has_spans?
      return false unless self.class.column_names.include?("spans")

      spans.present? && parsed_spans.any?
    end

    def has_profile?
      return false unless self.class.column_names.include?("has_profile")

      self[:has_profile] == true
    end

    PERIODS = {
      "1h"  => { duration: 1.hour,   granularity: :minute },
      "6h"  => { duration: 6.hours,  granularity: :minute },
      "24h" => { duration: 24.hours, granularity: :hour },
      "7d"  => { duration: 7.days,   granularity: :hour },
      "30d" => { duration: 30.days,  granularity: :day }
    }.freeze

    ERROR_COUNT_SQL = "SUM(CASE WHEN status >= 500 THEN 1 ELSE 0 END)".freeze

    class << self
      def slowest_endpoints(since: 24.hours.ago, limit: 20)
        where("created_at >= ?", since)
          .group(:endpoint)
          .select(
            "endpoint",
            "COUNT(*) AS request_count",
            "AVG(duration_ms) AS avg_duration",
            "AVG(db_runtime_ms) AS avg_db_runtime",
            "AVG(db_query_count) AS avg_query_count",
            percentile_select("duration_ms", 95, "p95_duration"),
            percentile_select("duration_ms", 50, "p50_duration"),
            "#{ERROR_COUNT_SQL} AS error_count"
          )
          .order(Arel.sql("AVG(duration_ms) DESC"))
          .limit(limit)
      end

      def endpoints_paginated(since: 24.hours.ago, search: nil, sort: "request_count", dir: :desc, page: 1, per_page: 25)
        base = where("created_at >= ?", since)
        base = base.where("endpoint LIKE ?", "%#{sanitize_sql_like(search)}%") if search.present?

        # Get total count of unique endpoints
        total_count = base.distinct.count(:endpoint)
        total_pages = [(total_count.to_f / per_page).ceil, 1].max
        page = [[page, 1].max, total_pages].min

        # Build the order clause based on sort column
        order_sql = case sort
                    when "endpoint"
                      "endpoint #{dir == :asc ? 'ASC' : 'DESC'}"
                    when "avg_duration"
                      "AVG(duration_ms) #{dir == :asc ? 'ASC' : 'DESC'}"
                    when "p95_duration"
                      "#{percentile_order_sql('duration_ms', 95)} #{dir == :asc ? 'ASC' : 'DESC'}"
                    when "request_count"
                      "COUNT(*) #{dir == :asc ? 'ASC' : 'DESC'}"
                    when "avg_db_runtime"
                      "AVG(db_runtime_ms) #{dir == :asc ? 'ASC' : 'DESC'}"
                    when "avg_query_count"
                      "AVG(db_query_count) #{dir == :asc ? 'ASC' : 'DESC'}"
                    when "error_rate"
                      "CAST(SUM(CASE WHEN status >= 500 THEN 1 ELSE 0 END) AS FLOAT) / NULLIF(COUNT(*), 0) #{dir == :asc ? 'ASC' : 'DESC'}"
                    else
                      "COUNT(*) DESC"
                    end

        records = base
          .group(:endpoint)
          .select(
            "endpoint",
            "COUNT(*) AS request_count",
            "AVG(duration_ms) AS avg_duration",
            "AVG(db_runtime_ms) AS avg_db_runtime",
            "AVG(db_query_count) AS avg_query_count",
            percentile_select("duration_ms", 95, "p95_duration"),
            percentile_select("duration_ms", 50, "p50_duration"),
            "#{ERROR_COUNT_SQL} AS error_count"
          )
          .order(Arel.sql(order_sql))
          .offset((page - 1) * per_page)
          .limit(per_page)

        { records: records, total_count: total_count, total_pages: total_pages }
      end

      def response_time_series(period: "24h", endpoint: nil)
        config = PERIODS[period] || PERIODS["24h"]
        base = where("created_at >= ?", config[:duration].ago)
        base = base.for_endpoint(endpoint) if endpoint
        group_expr = date_trunc_sql(config[:granularity])

        base.group(Arel.sql(group_expr))
            .order(Arel.sql(group_expr))
            .pluck(
              Arel.sql(group_expr),
              Arel.sql("AVG(duration_ms)"),
              Arel.sql("MAX(duration_ms)"),
              Arel.sql("MIN(duration_ms)"),
              Arel.sql("COUNT(*)")
            ).map do |bucket, avg, max, min, count|
              {
                bucket: bucket,
                avg: avg&.round(1),
                max: max&.round(1),
                min: min&.round(1),
                count: count
              }
            end
      end

      def throughput_series(period: "24h")
        config = PERIODS[period] || PERIODS["24h"]
        scope = where("created_at >= ?", config[:duration].ago)
        group_expr = date_trunc_sql(config[:granularity])

        scope.group(Arel.sql(group_expr))
             .order(Arel.sql(group_expr))
             .count
      end

      def summary_stats(since: 24.hours.ago)
        scope = where("created_at >= ?", since)

        # Single query for all basic aggregates
        row = scope.pick(
          Arel.sql("COUNT(*)"),
          Arel.sql("AVG(duration_ms)"),
          Arel.sql("AVG(db_runtime_ms)"),
          Arel.sql("AVG(db_query_count)"),
          Arel.sql(ERROR_COUNT_SQL)
        )

        total, avg_duration, avg_db_runtime, avg_query_count, error_count = row || [0, 0, 0, 0, 0]

        {
          total_requests: total || 0,
          avg_duration: avg_duration&.round(1) || 0,
          avg_db_runtime: avg_db_runtime&.round(1) || 0,
          avg_query_count: avg_query_count&.round(1) || 0,
          error_count: error_count || 0,
          p95_duration: percentile_value(scope, :duration_ms, 95, total)
        }
      end

      def cleanup!(before: nil)
        retention = before || Faultline.configuration.apm_retention_days.days.ago
        where("created_at < ?", retention).delete_all
      end

      def supports_percentile?
        connection.adapter_name.downcase.include?("postgresql")
      rescue StandardError
        false
      end

      def table_exists_for_apm?
        connection.table_exists?("faultline_request_traces")
      rescue StandardError
        false
      end

      private

      def percentile_value(scope, column, percentile, count = nil)
        count ||= scope.count
        return 0 if count == 0

        adapter = connection.adapter_name.downcase

        # PostgreSQL has native percentile support - much faster
        if adapter.include?("postgresql")
          scope.pick(
            Arel.sql("PERCENTILE_CONT(#{percentile / 100.0}) WITHIN GROUP (ORDER BY #{column})")
          )&.round(1) || 0
        else
          # Fallback: ORDER BY + OFFSET (slower but works everywhere)
          offset = ((percentile / 100.0) * count).ceil - 1
          scope.order(column).offset([offset, 0].max).limit(1).pick(column)&.round(1) || 0
        end
      end

      def percentile_select(column, percentile, as_name)
        adapter = connection.adapter_name.downcase
        if adapter.include?("postgresql")
          "PERCENTILE_CONT(#{percentile / 100.0}) WITHIN GROUP (ORDER BY #{column}) AS #{as_name}"
        else
          "MAX(#{column}) AS #{as_name}"
        end
      end

      def percentile_order_sql(column, percentile)
        adapter = connection.adapter_name.downcase
        if adapter.include?("postgresql")
          "PERCENTILE_CONT(#{percentile / 100.0}) WITHIN GROUP (ORDER BY #{column})"
        else
          "MAX(#{column})"
        end
      end

    end
  end
end
