# frozen_string_literal: true

module Faultline
  module Notifiers
    class Email < Base
      def initialize(to:, from: nil)
        @to = Array(to)
        @from = from
      end

      def call(error_group, error_occurrence)
        from_address = @from || default_from_address

        Faultline::ErrorMailer.error_notification(
          error_group: error_group,
          error_occurrence: error_occurrence,
          to: @to,
          from: from_address
        ).deliver_later
      rescue => e
        Rails.logger.error "[Faultline] Email notification failed: #{e.message}"
        raise unless Rails.env.production?
      end

      private

      def default_from_address
        ActionMailer::Base.default[:from] || "errors@#{default_host}"
      end

      def default_host
        ActionMailer::Base.default_url_options[:host] || "localhost"
      end
    end
  end
end
