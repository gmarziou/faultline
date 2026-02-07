# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::TracesController, type: :request do
  before do
    allow(Faultline.configuration).to receive(:authenticate_with).and_return(->(_) { true })
  end

  describe "GET /faultline/traces/:id" do
    let!(:trace) { create(:request_trace, endpoint: "UsersController#show") }

    it "returns success" do
      get "/faultline/traces/#{trace.id}"
      expect(response).to have_http_status(:ok)
    end

    it "displays trace information" do
      get "/faultline/traces/#{trace.id}"
      expect(response.body).to include(trace.path)
    end

    it "displays HTTP method" do
      get "/faultline/traces/#{trace.id}"
      expect(response.body).to include(trace.http_method)
    end

    it "displays duration" do
      get "/faultline/traces/#{trace.id}"
      expect(response.body).to include("Duration")
    end

    it "displays no spans message when spans not present" do
      get "/faultline/traces/#{trace.id}"
      expect(response.body).to include("No spans captured")
    end

    it "displays no profile message when profile not present" do
      get "/faultline/traces/#{trace.id}"
      expect(response.body).to include("No profile captured")
    end
  end

  describe "GET /faultline/traces/:id/profile" do
    let!(:trace) { create(:request_trace, endpoint: "UsersController#show") }

    it "returns 404 when no profile exists" do
      get "/faultline/traces/#{trace.id}/profile"
      expect(response).to have_http_status(:not_found)
    end
  end
end
