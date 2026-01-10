# frozen_string_literal: true

module Faultline
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    self.table_name_prefix = "faultline_"
  end
end
