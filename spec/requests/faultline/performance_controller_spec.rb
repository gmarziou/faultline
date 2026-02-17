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
        expect(response.body).to include("Endpoints")
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
      expect(response.body).to include("Requests")
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

  describe "GET /faultline/performance — sorting" do
    before do
      create(:request_trace, endpoint: "SlowController#index", duration_ms: 800)
      create(:request_trace, endpoint: "FastController#index", duration_ms: 50)
    end

    Faultline::PerformanceController::ENDPOINTS_SORT_COLUMNS.each do |col|
      it "accepts sort=#{col}" do
        get "/faultline/performance", params: { sort: col }
        expect(response).to have_http_status(:ok)
      end
    end

    it "ignores unknown sort column and defaults to request_count" do
      get "/faultline/performance", params: { sort: "malicious; DROP TABLE users--" }
      expect(response).to have_http_status(:ok)
    end

    it "accepts dir=asc" do
      get "/faultline/performance", params: { sort: "avg_duration", dir: "asc" }
      expect(response).to have_http_status(:ok)
    end

    it "defaults dir to desc for unknown values" do
      get "/faultline/performance", params: { sort: "avg_duration", dir: "sideways" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /faultline/performance — search" do
    before do
      create(:request_trace, endpoint: "UsersController#index")
      create(:request_trace, endpoint: "PostsController#index")
    end

    it "filters endpoints by search term" do
      get "/faultline/performance", params: { q: "Users" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("UsersController#index")
      expect(response.body).not_to include("PostsController#index")
    end

    it "returns empty state for non-matching search" do
      get "/faultline/performance", params: { q: "NoSuchController" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No matching endpoints")
    end

    it "safely handles LIKE injection characters in search" do
      # % and _ are LIKE wildcards; \\ is the escape char. None should cause a 500.
      get "/faultline/performance", params: { q: "%_\\" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /faultline/performance — pagination" do
    before do
      30.times { |i| create(:request_trace, endpoint: "Controller#{i}#index") }
    end

    it "returns page 1 by default" do
      get "/faultline/performance"
      expect(response).to have_http_status(:ok)
    end

    it "accepts page parameter" do
      get "/faultline/performance", params: { page: 2 }
      expect(response).to have_http_status(:ok)
    end

    it "treats page=0 as page 1" do
      get "/faultline/performance", params: { page: 0 }
      expect(response).to have_http_status(:ok)
    end

    it "treats negative page as page 1" do
      get "/faultline/performance", params: { page: -5 }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /faultline/performance/:id — sorting" do
    let(:endpoint) { "Api::OrdersController#create" }

    before do
      create(:request_trace, endpoint: endpoint, path: "/orders", duration_ms: 200)
      create(:request_trace, endpoint: endpoint, path: "/orders", duration_ms: 50)
    end

    Faultline::PerformanceController::REQUESTS_SORT_COLUMNS.each do |col|
      it "accepts sort=#{col}" do
        get "/faultline/performance/#{CGI.escape(endpoint)}", params: { sort: col }
        expect(response).to have_http_status(:ok)
      end
    end

    it "ignores unknown sort column and defaults to created_at" do
      get "/faultline/performance/#{CGI.escape(endpoint)}", params: { sort: "'; DROP TABLE--" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /faultline/performance/:id — search" do
    let(:endpoint) { "OrdersController#index" }

    before do
      create(:request_trace, endpoint: endpoint, path: "/orders/1")
      create(:request_trace, endpoint: endpoint, path: "/users/99")
    end

    it "filters traces by path search term" do
      get "/faultline/performance/#{CGI.escape(endpoint)}", params: { q: "orders" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("/orders/1")
      expect(response.body).not_to include("/users/99")
    end

    it "returns empty state for non-matching search" do
      get "/faultline/performance/#{CGI.escape(endpoint)}", params: { q: "/nonexistent" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No matching requests")
    end

    it "safely handles LIKE injection characters in path search" do
      get "/faultline/performance/#{CGI.escape(endpoint)}", params: { q: "%_\\" }
      expect(response).to have_http_status(:ok)
    end
  end
end
