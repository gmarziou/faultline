# frozen_string_literal: true

module Faultline
  module Notifiers
    class Base
      attr_reader :options

      def initialize(options = {})
        @options = options
      end

      def call(error_group, error_occurrence)
        raise NotImplementedError, "Subclasses must implement #call"
      end

      # Extension point for per-notifier filtering. Global rules (environment,
      # cooldown, threshold, first-occurrence) are evaluated by Tracker before
      # Faultline.notify is called, so this hook is for notifier-specific logic
      # only — e.g. a notifier that only fires for certain exception classes.
      # The base implementation allows all notifications through.
      def should_notify?(error_group, error_occurrence)
        true
      end

      protected

      def format_message(error_group, error_occurrence)
        {
          title: "Error in #{app_name}",
          exception_class: error_group.exception_class,
          message: error_group.sanitized_message.to_s.truncate(200),
          occurrences: error_group.occurrences_count,
          status: error_group.status,
          location: format_location(error_group),
          user: error_occurrence.user_identifier,
          url: error_occurrence.request_url,
          method: error_occurrence.request_method,
          timestamp: error_occurrence.created_at,
          reopened: error_group.recently_reopened?
        }
      end

      def app_name
        Faultline.configuration.resolved_app_name
      end

      def format_location(error_group)
        parts = [error_group.file_path, error_group.line_number].compact
        parts.any? ? parts.join(":") : "unknown"
      end

      def status_emoji(error_group)
        return "\u{1F504}" if error_group.recently_reopened? # 🔄
        error_group.occurrences_count == 1 ? "\u{1F6A8}" : "\u{26A0}\u{FE0F}" # 🚨 or ⚠️
      end
    end
  end
end
