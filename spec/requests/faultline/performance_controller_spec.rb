# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Faultline::PerformanceController", type: :request do
  before do
    # Clear cache to prevent test pollution
    Rails.cache.clear
    # Disable authentication/authorization for tests
    allow(Faultline.configuration).to receive(:authenticate_with).and_return(nil)
    allow(Faultline.configuration).to receive(:authorize_with).and_return(nil)
    allow(Faultline.configuration).to receive(:enable_apm).and_return(true)
    # Disable CSRF protection for tests
    ActionController::Base.allow_forgery_protection = false
  end

  after do
    ActionController::Base.allow_forgery_protection = true
    Rails.cache.clear
  end

  describe "GET /faultline/performance" do
    it "returns success" do
      get "/faultline/performance"
      expect(response).to have_http_status(:ok)
    end

    it "displays summary stats" do
      create(:request_trace, duration_ms: 100)
      create(:request_trace, duration_ms: 200)

      get "/faultline/performance"

      expect(response.body).to include("Performance")
      expect(response.body).to include("Total Requests")
    end

    context "with period parameter" do
      it "accepts 1h period" do
        get "/faultline/performance", params: { period: "1h" }
        expect(response).to have_http_status(:ok)
      end

      it "accepts 24h period" do
        get "/faultline/performance", params: { period: "24h" }
        expect(response).to have_http_status(:ok)
      end

      it "accepts 7d period" do
        get "/faultline/performance", params: { period: "7d" }
        expect(response).to have_http_status(:ok)
      end

      it "accepts 30d period" do
        get "/faultline/performance", params: { period: "30d" }
        expect(response).to have_http_status(:ok)
      end

      it "defaults to 24h for invalid period" do
        get "/faultline/performance", params: { period: "invalid" }
        expect(response).to have_http_status(:ok)
      end
    end

    context "with slowest endpoints" do
      it "displays slowest endpoints table" do
        create(:request_trace, endpoint: "UsersController#index", duration_ms: 500)
        create(:request_trace, endpoint: "PostsController#index", duration_ms: 100)

        get "/faultline/performance"

        expect(response.body).to include("UsersController#index")
        expect(response.body).to include("Slowest Endpoints")
      end
    end

    context "with no data" do
      it "displays empty state" do
        get "/faultline/performance"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("No performance data yet")
      end
    end
  end

  describe "GET /faultline/performance/:id" do
    let(:endpoint) { "UsersController#show" }

    before do
      3.times do
        create(:request_trace, endpoint: endpoint, duration_ms: rand(100..300))
      end
    end

    it "returns success" do
      get "/faultline/performance/#{CGI.escape(endpoint)}"
      expect(response).to have_http_status(:ok)
    end

    it "displays endpoint name" do
      get "/faultline/performance/#{CGI.escape(endpoint)}"
      expect(response.body).to include("UsersController#show")
    end

    it "displays endpoint stats" do
      get "/faultline/performance/#{CGI.escape(endpoint)}"

      expect(response.body).to include("Requests")
      expect(response.body).to include("Avg")
      expect(response.body).to include("Min")
      expect(response.body).to include("Max")
    end

    it "displays individual traces" do
      get "/faultline/performance/#{CGI.escape(endpoint)}"
      expect(response.body).to include("Slowest Requests")
    end

    context "with period parameter" do
      it "accepts period parameter" do
        get "/faultline/performance/#{CGI.escape(endpoint)}", params: { period: "7d" }
        expect(response).to have_http_status(:ok)
      end
    end

    context "with pagination" do
      before do
        30.times do
          create(:request_trace, endpoint: endpoint, duration_ms: rand(100..500))
        end
      end

      it "paginates results" do
        get "/faultline/performance/#{CGI.escape(endpoint)}", params: { page: 2 }
        expect(response).to have_http_status(:ok)
      end
    end

    context "with no data for endpoint" do
      it "displays empty state" do
        get "/faultline/performance/#{CGI.escape("NonExistentController#action")}"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("No traces yet")
      end
    end
  end

  describe "endpoint with special characters" do
    it "handles # in endpoint name" do
      create(:request_trace, endpoint: "Api::V1::UsersController#index", duration_ms: 100)

      get "/faultline/performance/#{CGI.escape('Api::V1::UsersController#index')}"
      expect(response).to have_http_status(:ok)
    end
  end
end
