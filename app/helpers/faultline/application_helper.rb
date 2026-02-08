# frozen_string_literal: true

module Faultline
  module ApplicationHelper
    def status_badge_class(status)
      case status
      when "unresolved"
        "bg-rose-500/10 text-rose-500 border border-rose-500/20"
      when "resolved"
        "bg-emerald-500/10 text-emerald-500 border border-emerald-500/20"
      when "ignored"
        "bg-slate-500/10 text-slate-500 border border-slate-500/20"
      else
        "bg-slate-500/10 text-slate-500 border border-slate-500/20"
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

    def http_status_class(status)
      case status.to_i
      when 200..299
        "text-emerald-600 dark:text-emerald-400"
      when 300..399
        "text-blue-600 dark:text-blue-400"
      when 400..499
        "text-amber-600 dark:text-amber-400"
      when 500..599
        "text-rose-600 dark:text-rose-400"
      else
        "text-slate-500"
      end
    end

    def format_duration(ms)
      return "-" if ms.nil?

      if ms >= 1000
        "#{(ms / 1000.0).round(2)}s"
      else
        "#{ms.round(1)}ms"
      end
    end

    def sortable_header(column, label, path_helper:, path_params:, current_sort:, current_dir:, align: :left)
      is_current = current_sort == column.to_s
      new_dir = is_current && current_dir == :desc ? "asc" : "desc"
      icon = is_current ? (current_dir == :desc ? "arrow_downward" : "arrow_upward") : "unfold_more"
      icon_class = is_current ? "text-primary" : "text-slate-300 dark:text-slate-600 opacity-0 group-hover:opacity-100"

      align_class = { left: "text-left", center: "text-center", right: "text-right" }[align]
      justify_class = { left: "", center: "justify-center", right: "justify-end" }[align]

      content_tag(:th, class: "#{align_class} px-6 py-3 text-xs font-bold text-slate-400 uppercase tracking-wider") do
        link_to send(path_helper, path_params.merge(sort: column, dir: new_dir, page: 1)),
                class: "group inline-flex items-center gap-1 w-full #{justify_class}" do
          concat content_tag(:span, label)
          concat content_tag(:span, icon, class: "material-symbols-outlined text-sm #{icon_class} transition-opacity")
        end
      end
    end

    def highlight_ruby(code)
      return "" if code.blank?

      tokens = []
      scanner = StringScanner.new(code)

      until scanner.eos?
        if scanner.scan(/#.*/)
          tokens << %(<span class="text-slate-400 italic">#{h(scanner.matched)}</span>)
        elsif scanner.scan(/"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'/)
          tokens << %(<span class="text-emerald-600 dark:text-emerald-400">#{h(scanner.matched)}</span>)
        elsif scanner.scan(/:\w+/)
          tokens << %(<span class="text-purple-600 dark:text-purple-400">#{h(scanner.matched)}</span>)
        elsif scanner.scan(/@\w+/)
          tokens << %(<span class="text-primary">#{h(scanner.matched)}</span>)
        elsif scanner.scan(/\b(def|end|class|module|if|else|elsif|unless|case|when|then|do|begin|rescue|ensure|raise|return|yield|while|until|for|break|next|retry|self|true|false|nil|and|or|not|in)\b/)
          tokens << %(<span class="text-rose-600 dark:text-rose-400 font-medium">#{h(scanner.matched)}</span>)
        elsif scanner.scan(/\b\d+\.?\d*\b/)
          tokens << %(<span class="text-blue-600 dark:text-blue-400">#{h(scanner.matched)}</span>)
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
