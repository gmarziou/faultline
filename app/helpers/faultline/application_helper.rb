# frozen_string_literal: true

module Faultline
  module ApplicationHelper
    def status_badge_class(status)
      case status
      when "unresolved"
        "bg-red-100 text-red-800"
      when "resolved"
        "bg-green-100 text-green-800"
      when "ignored"
        "bg-gray-100 text-gray-800"
      else
        "bg-gray-100 text-gray-800"
      end
    end

    def time_ago_in_words_short(time)
      return "never" unless time

      seconds = (Time.current - time).to_i

      case seconds
      when 0..59 then "#{seconds}s"
      when 60..3599 then "#{seconds / 60}m"
      when 3600..86399 then "#{seconds / 3600}h"
      else "#{seconds / 86400}d"
      end
    end
  end
end
