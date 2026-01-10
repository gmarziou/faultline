# frozen_string_literal: true

module Faultline
  class ErrorOccurrencesController < ApplicationController
    def index
      @occurrences = ErrorOccurrence.recent.includes(:error_group)

      if params[:error_group_id].present?
        @error_group = ErrorGroup.find(params[:error_group_id])
        @occurrences = @occurrences.where(error_group: @error_group)
      end

      @occurrences = @occurrences.page(params[:page]).per(25)
    end

    def show
      @occurrence = ErrorOccurrence.find(params[:id])
      @error_group = @occurrence.error_group
    end
  end
end
