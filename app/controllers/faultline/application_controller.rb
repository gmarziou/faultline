# frozen_string_literal: true

module Faultline
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    layout "faultline/application"

    before_action :authenticate!
    before_action :authorize!

    helper_method :current_faultline_user

    private

    def authenticate!
      config = Faultline.configuration

      return unless config.authenticate_with

      unless instance_exec(request, &config.authenticate_with)
        render_unauthorized
      end
    end

    def authorize!
      config = Faultline.configuration

      return unless config.authorize_with

      unless instance_exec(request, &config.authorize_with)
        render_forbidden
      end
    end

    def current_faultline_user
      return @current_faultline_user if defined?(@current_faultline_user)

      @current_faultline_user = begin
        config = Faultline.configuration

        if defined?(current_user)
          current_user
        elsif session[:user_id] && config.user_class_constant
          config.user_class_constant.find_by(id: session[:user_id])
        end
      rescue
        nil
      end
    end

    def render_unauthorized
      respond_to do |format|
        format.html { render plain: "Unauthorized", status: :unauthorized }
        format.json { render json: { error: "Unauthorized" }, status: :unauthorized }
      end
    end

    def render_forbidden
      respond_to do |format|
        format.html { render plain: "Forbidden", status: :forbidden }
        format.json { render json: { error: "Forbidden" }, status: :forbidden }
      end
    end
  end
end
