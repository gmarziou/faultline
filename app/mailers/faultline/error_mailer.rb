# frozen_string_literal: true

module Faultline
  class ErrorMailer < ApplicationMailer
    def error_notification(error_group:, error_occurrence:, to:, from:)
      @error_group = error_group
      @occurrence = error_occurrence
      @app_name = Faultline.configuration.resolved_app_name

      mail(
        to: to,
        from: from,
        subject: build_subject
      )
    end

    private

    def build_subject
      prefix = @error_group.recently_reopened? ? "[REOPENED]" : "[ERROR]"
      "#{prefix} #{@app_name}: #{@error_group.exception_class}"
    end
  end
end
