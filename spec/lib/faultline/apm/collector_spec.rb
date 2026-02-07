# frozen_string_literal: true

require "rails_helper"
require "faultline/apm/collector"

RSpec.describe Faultline::Apm::Collector do
  # Track if we started the collector in this test
  let(:collector_started) { false }

  before(:each) do
    # Aggressively stop and reset before each test
    described_class.stop!
    Thread.current[described_class::THREAD_KEY] = nil
    # Clear any existing RequestTraces
    Faultline::RequestTrace.delete_all
  end

  after(:each) do
    described_class.stop!
    Thread.current[described_class::THREAD_KEY] = nil
  end

  describe ".start!" do
    it "subscribes to sql.active_record notifications" do
      # Verify subscription by checking the callback fires
      described_class.start!

      Thread.current[described_class::THREAD_KEY] = nil
      ActiveSupport::Notifications.instrument("sql.active_record", name: "User Load", sql: "SELECT * FROM users") { }

      expect(Thread.current[described_class::THREAD_KEY]).to eq(1)
    end

    it "subscribes to process_action.action_controller notifications" do
      allow(Faultline.configuration).to receive(:enable_apm).and_return(true)
      allow(Faultline.configuration).to receive(:apm_sample_rate).and_return(1.0)
      allow(Faultline.configuration).to receive(:resolved_apm_ignore_paths).and_return([])
      described_class.start!

      expect {
        ActiveSupport::Notifications.instrument("process_action.action_controller", {
          controller: "TestController",
          action: "test",
          method: "GET",
          path: "/test"
        }) { }
      }.to change(Faultline::RequestTrace, :count)
    end
  end

  describe ".stop!" do
    it "unsubscribes from notifications" do
      described_class.start!

      # 3 subscribers: start_processing, sql, and process_action
      expect(ActiveSupport::Notifications).to receive(:unsubscribe).exactly(3).times.and_call_original
      described_class.stop!
    end
  end

  describe "SQL query counting" do
    before(:each) do
      # Ensure completely clean state before starting
      described_class.stop!
      Thread.current[described_class::THREAD_KEY] = nil

      allow(Faultline.configuration).to receive(:enable_apm).and_return(true)
      described_class.start!
    end

    after(:each) do
      described_class.stop!
    end

    it "increments thread-local counter on SQL events" do
      # Simulate SQL notification
      ActiveSupport::Notifications.instrument("sql.active_record", name: "User Load", sql: "SELECT * FROM users") do
        # query executed
      end

      expect(Thread.current[described_class::THREAD_KEY]).to eq(1)
    end

    it "ignores SCHEMA queries" do
      ActiveSupport::Notifications.instrument("sql.active_record", name: "SCHEMA", sql: "PRAGMA table_info") do
        # schema query
      end

      expect(Thread.current[described_class::THREAD_KEY]).to be_nil
    end

    it "ignores EXPLAIN queries" do
      ActiveSupport::Notifications.instrument("sql.active_record", name: "EXPLAIN for: SELECT", sql: "EXPLAIN SELECT") do
        # explain query
      end

      expect(Thread.current[described_class::THREAD_KEY]).to be_nil
    end
  end

  describe "action processing" do
    let(:event_payload) do
      {
        controller: "UsersController",
        action: "index",
        method: "GET",
        path: "/users",
        status: 200,
        db_runtime: 15.5,
        view_runtime: 25.3
      }
    end

    before(:each) do
      # Ensure completely clean state
      described_class.stop!
      Thread.current[described_class::THREAD_KEY] = nil

      allow(Faultline.configuration).to receive(:enable_apm).and_return(true)
      allow(Faultline.configuration).to receive(:apm_sample_rate).and_return(1.0)
      allow(Faultline.configuration).to receive(:resolved_apm_ignore_paths).and_return(["/faultline", "/assets"])
      described_class.start!
    end

    after(:each) do
      described_class.stop!
    end

    it "creates a RequestTrace on action completion" do
      Thread.current[described_class::THREAD_KEY] = 5

      expect {
        ActiveSupport::Notifications.instrument("process_action.action_controller", event_payload) do
          # action executed
        end
      }.to change(Faultline::RequestTrace, :count).by(1)
    end

    it "stores correct endpoint format" do
      ActiveSupport::Notifications.instrument("process_action.action_controller", event_payload) do
        # action executed
      end

      trace = Faultline::RequestTrace.last
      expect(trace.endpoint).to eq("UsersController#index")
    end

    it "stores HTTP method" do
      ActiveSupport::Notifications.instrument("process_action.action_controller", event_payload) do
        # action executed
      end

      trace = Faultline::RequestTrace.last
      expect(trace.http_method).to eq("GET")
    end

    it "stores path without query string" do
      payload = event_payload.merge(path: "/users?page=1&sort=name")

      ActiveSupport::Notifications.instrument("process_action.action_controller", payload) do
        # action executed
      end

      trace = Faultline::RequestTrace.last
      expect(trace.path).to eq("/users")
    end

    it "stores status code" do
      ActiveSupport::Notifications.instrument("process_action.action_controller", event_payload) do
        # action executed
      end

      trace = Faultline::RequestTrace.last
      expect(trace.status).to eq(200)
    end

    it "stores db_runtime" do
      ActiveSupport::Notifications.instrument("process_action.action_controller", event_payload) do
        # action executed
      end

      trace = Faultline::RequestTrace.last
      expect(trace.db_runtime_ms).to eq(15.5)
    end

    it "stores view_runtime" do
      ActiveSupport::Notifications.instrument("process_action.action_controller", event_payload) do
        # action executed
      end

      trace = Faultline::RequestTrace.last
      expect(trace.view_runtime_ms).to eq(25.3)
    end

    it "stores query count from thread-local counter" do
      Thread.current[described_class::THREAD_KEY] = 12

      ActiveSupport::Notifications.instrument("process_action.action_controller", event_payload) do
        # action executed
      end

      trace = Faultline::RequestTrace.last
      expect(trace.db_query_count).to eq(12)
    end

    it "resets thread-local counter after processing" do
      Thread.current[described_class::THREAD_KEY] = 10

      ActiveSupport::Notifications.instrument("process_action.action_controller", event_payload) do
        # action executed
      end

      expect(Thread.current[described_class::THREAD_KEY]).to eq(0)
    end

    it "sets status to 500 when exception is present and status is nil" do
      payload = event_payload.merge(status: nil, exception: ["RuntimeError", "Something went wrong"])

      ActiveSupport::Notifications.instrument("process_action.action_controller", payload) do
        # action with exception
      end

      trace = Faultline::RequestTrace.last
      expect(trace.status).to eq(500)
    end

    context "when APM is disabled" do
      before do
        allow(Faultline.configuration).to receive(:enable_apm).and_return(false)
      end

      it "does not create a RequestTrace" do
        expect {
          ActiveSupport::Notifications.instrument("process_action.action_controller", event_payload) do
            # action executed
          end
        }.not_to change(Faultline::RequestTrace, :count)
      end
    end

    context "when path should be ignored" do
      it "does not create trace for ignored paths" do
        payload = event_payload.merge(path: "/faultline/error_groups")

        expect {
          ActiveSupport::Notifications.instrument("process_action.action_controller", payload) do
            # action executed
          end
        }.not_to change(Faultline::RequestTrace, :count)
      end

      it "does not create trace for asset paths" do
        payload = event_payload.merge(path: "/assets/application.js")

        expect {
          ActiveSupport::Notifications.instrument("process_action.action_controller", payload) do
            # action executed
          end
        }.not_to change(Faultline::RequestTrace, :count)
      end
    end

    context "with sampling" do
      before do
        allow(Faultline.configuration).to receive(:apm_sample_rate).and_return(0.5)
      end

      it "respects sample rate" do
        traces_created = 0
        100.times do
          ActiveSupport::Notifications.instrument("process_action.action_controller", event_payload) do
            # action executed
          end
          traces_created = Faultline::RequestTrace.count
        end

        # With 50% sampling, we should have roughly 50 traces (allow for randomness)
        expect(traces_created).to be_between(20, 80)
      end
    end

    context "when sample rate is 0" do
      before do
        allow(Faultline.configuration).to receive(:apm_sample_rate).and_return(0.0)
      end

      it "does not create any traces" do
        expect {
          10.times do
            ActiveSupport::Notifications.instrument("process_action.action_controller", event_payload) do
              # action executed
            end
          end
        }.not_to change(Faultline::RequestTrace, :count)
      end
    end
  end

  describe "error handling" do
    before(:each) do
      described_class.stop!
      Thread.current[described_class::THREAD_KEY] = nil

      allow(Faultline.configuration).to receive(:enable_apm).and_return(true)
      allow(Faultline.configuration).to receive(:apm_sample_rate).and_return(1.0)
      allow(Faultline.configuration).to receive(:resolved_apm_ignore_paths).and_return([])
      described_class.start!
    end

    after(:each) do
      described_class.stop!
    end

    it "does not raise when RequestTrace creation fails" do
      allow(Faultline::RequestTrace).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

      expect {
        ActiveSupport::Notifications.instrument("process_action.action_controller", {
          controller: "UsersController",
          action: "index",
          path: "/users",
          method: "GET"
        }) { }
      }.not_to raise_error
    end

    it "still resets thread counter on error" do
      Thread.current[described_class::THREAD_KEY] = 10
      allow(Faultline::RequestTrace).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

      ActiveSupport::Notifications.instrument("process_action.action_controller", {
        controller: "UsersController",
        action: "index",
        path: "/users",
        method: "GET"
      }) { }

      expect(Thread.current[described_class::THREAD_KEY]).to eq(0)
    end
  end
end
