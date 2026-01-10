# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Faultline
  module Notifiers
    class Webhook < Base
      def initialize(url:, method: :post, headers: {}, **options)
        super(options)
        @url = url
        @method = method.to_sym
        @headers = headers
      end

      def call(error_group, error_occurrence)
        payload = format_webhook_payload(error_group, error_occurrence)
        send_request(payload)
      end

      private

      def format_webhook_payload(error_group, error_occurrence)
        {
          event: "error.occurred",
          timestamp: Time.current.iso8601,
          app: Faultline.configuration.resolved_app_name,
          environment: Rails.env,
          error_group: {
            id: error_group.id,
            fingerprint: error_group.fingerprint,
            exception_class: error_group.exception_class,
            message: error_group.sanitized_message,
            status: error_group.status,
            occurrences_count: error_group.occurrences_count,
            first_seen_at: error_group.first_seen_at&.iso8601,
            last_seen_at: error_group.last_seen_at&.iso8601,
            file_path: error_group.file_path,
            line_number: error_group.line_number,
            recently_reopened: error_group.recently_reopened?
          },
          occurrence: {
            id: error_occurrence.id,
            message: error_occurrence.message.to_s.truncate(500),
            request_url: error_occurrence.request_url,
            request_method: error_occurrence.request_method,
            user_id: error_occurrence.user_id,
            user_identifier: error_occurrence.user_identifier,
            ip_address: error_occurrence.ip_address,
            created_at: error_occurrence.created_at.iso8601
          }
        }
      end

      def send_request(payload)
        uri = URI(@url)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 5
        http.read_timeout = 10

        request = case @method
                  when :post then Net::HTTP::Post.new(uri)
                  when :put then Net::HTTP::Put.new(uri)
                  else raise ArgumentError, "Unsupported HTTP method: #{@method}"
                  end

        request["Content-Type"] = "application/json"
        @headers.each { |k, v| request[k.to_s] = v }
        request.body = payload.to_json

        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.error "[Faultline::Webhook] Request failed: #{response.code} #{response.body.to_s.truncate(200)}"
        end
      rescue => e
        Rails.logger.error "[Faultline::Webhook] Failed to send: #{e.message}"
      end
    end
  end
end
