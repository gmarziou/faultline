# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::ApplicationHelper, type: :helper do
  describe "#format_duration" do
    it "returns '-' for nil" do
      expect(helper.format_duration(nil)).to eq("-")
    end

    it "formats milliseconds below 1000" do
      expect(helper.format_duration(42.6)).to eq("42.6ms")
    end

    it "formats milliseconds at or above 1000 as seconds" do
      expect(helper.format_duration(1500)).to eq("1.5s")
    end

    it "rounds milliseconds to one decimal place" do
      expect(helper.format_duration(123.456)).to eq("123.5ms")
    end

    it "handles integer input" do
      expect(helper.format_duration(200)).to eq("200.0ms")
    end

    it "handles string input without raising (SQLite aggregate returns)" do
      expect { helper.format_duration("123.4") }.not_to raise_error
      expect(helper.format_duration("123.4")).to eq("123.4ms")
    end

    it "handles zero" do
      expect(helper.format_duration(0)).to eq("0.0ms")
    end
  end
end
