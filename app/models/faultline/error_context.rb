# frozen_string_literal: true

module Faultline
  class ErrorContext < ApplicationRecord
    belongs_to :error_occurrence, class_name: "Faultline::ErrorOccurrence"

    validates :key, presence: true

    def parsed_value
      JSON.parse(value)
    rescue
      value
    end
  end
end
