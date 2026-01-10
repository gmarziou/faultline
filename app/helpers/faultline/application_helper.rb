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

    def highlight_ruby(code)
      return "" if code.blank?

      tokens = []
      scanner = StringScanner.new(code)

      until scanner.eos?
        if scanner.scan(/#.*/)
          tokens << %(<span class="text-gray-400 italic">#{h(scanner.matched)}</span>)
        elsif scanner.scan(/"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'/)
          tokens << %(<span class="text-emerald-600">#{h(scanner.matched)}</span>)
        elsif scanner.scan(/:\w+/)
          tokens << %(<span class="text-purple-600">#{h(scanner.matched)}</span>)
        elsif scanner.scan(/@\w+/)
          tokens << %(<span class="text-cyan-600">#{h(scanner.matched)}</span>)
        elsif scanner.scan(/\b(def|end|class|module|if|else|elsif|unless|case|when|then|do|begin|rescue|ensure|raise|return|yield|while|until|for|break|next|retry|self|true|false|nil|and|or|not|in)\b/)
          tokens << %(<span class="text-rose-600 font-medium">#{h(scanner.matched)}</span>)
        elsif scanner.scan(/\b\d+\.?\d*\b/)
          tokens << %(<span class="text-blue-600">#{h(scanner.matched)}</span>)
        elsif scanner.scan(/\w+/)
          tokens << h(scanner.matched)
        else
          tokens << h(scanner.getch)
        end
      end

      tokens.join.html_safe
    end
  end
end
