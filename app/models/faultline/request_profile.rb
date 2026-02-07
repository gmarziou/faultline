# frozen_string_literal: true

module Faultline
  class RequestProfile < ApplicationRecord
    belongs_to :request_trace

    def decoded_profile
      Marshal.load(Base64.decode64(profile_data))
    end

    def to_speedscope_json
      SpeedscopeConverter.convert(decoded_profile)
    end

    def self.cleanup!(before: nil)
      retention = before || Faultline.configuration.apm_retention_days.days.ago
      joins(:request_trace).where("faultline_request_traces.created_at < ?", retention).delete_all
    end
  end
end
