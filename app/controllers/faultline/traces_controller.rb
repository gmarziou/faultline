# frozen_string_literal: true

module Faultline
  class TracesController < ApplicationController
    def show
      @trace = RequestTrace.find(params[:id])
      @spans = @trace.parsed_spans
      @has_profile = @trace.has_profile? && @trace.profile.present?
    end

    def profile
      trace = RequestTrace.find(params[:id])

      unless RequestProfile.table_exists?
        return render json: { error: "Profiles not available" }, status: :not_found
      end

      profile = trace.profile

      if profile
        render json: profile.to_speedscope_json
      else
        render json: { error: "No profile available" }, status: :not_found
      end
    end
  end
end
