# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Faultline
  module Notifiers
    class Slack < Base
      def initialize(webhook_url:, channel: nil, username: "Faultline", icon_emoji: ":rotating_light:", **options)
        super(options)
        @webhook_url = webhook_url
        @channel = channel
        @username = username
        @icon_emoji = icon_emoji
      end

      def call(error_group, error_occurrence)
        payload = format_slack_payload(error_group, error_occurrence)
        send_webhook(payload)
      end

      private

      def format_slack_payload(error_group, error_occurrence)
        data = format_message(error_group, error_occurrence)

        fields = [
          { title: "Exception", value: data[:exception_class], short: true },
          { title: "Occurrences", value: data[:occurrences].to_s, short: true },
          { title: "Location", value: data[:location], short: true }
        ]

        fields << { title: "User", value: data[:user], short: true } if data[:user]

        if data[:url]
          fields << { title: "URL", value: "#{data[:method]} #{data[:url].to_s.truncate(80)}", short: false }
        end

        attachment = {
          color: attachment_color(error_group),
          title: data[:message],
          fields: fields,
          footer: data[:title],
          ts: data[:timestamp]&.to_i
        }

        if data[:reopened]
          attachment[:pretext] = ":recycle: This error was previously resolved and has reoccurred."
        end

        payload = {
          username: @username,
          icon_emoji: @icon_emoji,
          attachments: [attachment]
        }

        payload[:channel] = @channel if @channel

        payload
      end

      def attachment_color(error_group)
        return "warning" if error_group.recently_reopened?
        "danger"
      end

      def send_webhook(payload)
        uri = URI(@webhook_url)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 5
        http.read_timeout = 5

        request = Net::HTTP::Post.new(uri.path)
        request["Content-Type"] = "application/json"
        request.body = payload.to_json

        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.error "[Faultline::Slack] Webhook error: #{response.code} #{response.body}"
        end
      rescue => e
        Rails.logger.error "[Faultline::Slack] Failed to send: #{e.message}"
      end
    end
  end
end
