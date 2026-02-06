# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Notifiers::Email do
  let(:to) { "team@example.com" }
  let(:from) { "errors@example.com" }
  let(:notifier) { described_class.new(to: to, from: from) }
  let(:error_group) { create(:error_group) }
  let(:occurrence) { create(:error_occurrence, error_group: error_group) }

  describe "#initialize" do
    it "sets to as array" do
      expect(notifier.instance_variable_get(:@to)).to eq(["team@example.com"])
    end

    it "accepts multiple recipients" do
      notifier = described_class.new(to: ["a@example.com", "b@example.com"], from: from)
      expect(notifier.instance_variable_get(:@to)).to eq(["a@example.com", "b@example.com"])
    end

    it "sets from address" do
      expect(notifier.instance_variable_get(:@from)).to eq("errors@example.com")
    end

    it "allows nil from (uses default)" do
      notifier = described_class.new(to: to)
      expect(notifier.instance_variable_get(:@from)).to be_nil
    end
  end

  describe "#call" do
    let(:mail_double) { double("Mail", deliver_later: true) }

    before do
      allow(Faultline::ErrorMailer).to receive(:error_notification).and_return(mail_double)
    end

    it "sends email via ErrorMailer" do
      expect(Faultline::ErrorMailer).to receive(:error_notification).with(
        error_group: error_group,
        error_occurrence: occurrence,
        to: ["team@example.com"],
        from: "errors@example.com"
      ).and_return(mail_double)

      notifier.call(error_group, occurrence)
    end

    it "delivers email asynchronously" do
      expect(mail_double).to receive(:deliver_later)
      notifier.call(error_group, occurrence)
    end

    context "when from is not specified" do
      let(:notifier) { described_class.new(to: to) }

      before do
        allow(ActionMailer::Base).to receive(:default).and_return({ from: "default@example.com" })
      end

      it "uses ActionMailer default from address" do
        expect(Faultline::ErrorMailer).to receive(:error_notification).with(
          hash_including(from: "default@example.com")
        ).and_return(mail_double)

        notifier.call(error_group, occurrence)
      end
    end

    context "when mailer fails in development" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
        allow(Faultline::ErrorMailer).to receive(:error_notification).and_raise(StandardError.new("SMTP error"))
      end

      it "re-raises the error" do
        expect { notifier.call(error_group, occurrence) }.to raise_error(StandardError, "SMTP error")
      end
    end

    context "when mailer fails in production" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
        allow(Faultline::ErrorMailer).to receive(:error_notification).and_raise(StandardError.new("SMTP error"))
      end

      it "logs error and does not raise" do
        expect(Rails.logger).to receive(:error).with(/Email notification failed/)
        expect { notifier.call(error_group, occurrence) }.not_to raise_error
      end
    end
  end
end
