# frozen_string_literal: true

namespace :faultline do
  namespace :apm do
    desc "Clean up old APM request traces and profiles based on apm_retention_days"
    task cleanup: :environment do
      traces_deleted = Faultline::RequestTrace.cleanup!
      puts "[Faultline APM] Cleaned up #{traces_deleted} old traces"

      if Faultline::RequestProfile.table_exists?
        profiles_deleted = Faultline::RequestProfile.cleanup!
        puts "[Faultline APM] Cleaned up #{profiles_deleted} old profiles"
      end
    end
  end
end
