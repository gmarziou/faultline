# frozen_string_literal: true

module Faultline
  # Provides a database-agnostic date_trunc_sql helper for grouping records
  # by time granularity in SQLite, MySQL, and PostgreSQL.
  #
  # Include in ActiveRecord model classes and extend at the class level:
  #
  #   class MyModel < ApplicationRecord
  #     extend Faultline::SqlTimeGrouping
  #   end
  #
  # Instance-level callers should delegate via self.class:
  #
  #   scope.group(Arel.sql(self.class.date_trunc_sql(:hour)))
  module SqlTimeGrouping
    def date_trunc_sql(granularity)
      adapter = connection.adapter_name.downcase

      case granularity
      when :minute
        if adapter.include?("postgresql")
          "date_trunc('minute', created_at)"
        elsif adapter.include?("mysql") || adapter.include?("trilogy")
          "DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:00')"
        else # SQLite
          "strftime('%Y-%m-%d %H:%M:00', created_at)"
        end
      when :hour
        if adapter.include?("postgresql")
          "date_trunc('hour', created_at)"
        elsif adapter.include?("mysql") || adapter.include?("trilogy")
          "DATE_FORMAT(created_at, '%Y-%m-%d %H:00:00')"
        else # SQLite
          "strftime('%Y-%m-%d %H:00:00', created_at)"
        end
      else # :day
        "DATE(created_at)"
      end
    end
  end
end
