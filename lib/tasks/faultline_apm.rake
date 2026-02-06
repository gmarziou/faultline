# frozen_string_literal: true

namespace :faultline do
  namespace :apm do
    desc "Clean up old APM request traces based on apm_retention_days"
    task cleanup: :environment do
      deleted = Faultline::RequestTrace.cleanup!
      puts "[Faultline APM] Cleaned up #{deleted} old traces"
    end
  end
end
