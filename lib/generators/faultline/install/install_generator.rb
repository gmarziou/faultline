# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Faultline
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Install Faultline error tracking engine"

      class_option :user_class, type: :string, default: "User",
                   desc: "The user class for association"

      def copy_initializer
        template "initializer.rb.tt", "config/initializers/faultline.rb"
      end

      def copy_migrations
        migration_template "migrations/create_faultline_error_groups.rb.tt",
                           "db/migrate/create_faultline_error_groups.rb"
        migration_template "migrations/create_faultline_error_occurrences.rb.tt",
                           "db/migrate/create_faultline_error_occurrences.rb"
        migration_template "migrations/create_faultline_error_contexts.rb.tt",
                           "db/migrate/create_faultline_error_contexts.rb"
        migration_template "migrations/create_faultline_request_traces.rb.tt",
                           "db/migrate/create_faultline_request_traces.rb"
      end

      def add_route
        route 'mount Faultline::Engine, at: "/faultline"'
      end

      def show_post_install
        say ""
        say "=" * 60, :green
        say " Faultline has been installed!", :green
        say "=" * 60, :green
        say ""
        say "Next steps:", :yellow
        say ""
        say "  1. Run migrations:"
        say "     rails db:migrate", :cyan
        say ""
        say "  2. Configure authentication in:"
        say "     config/initializers/faultline.rb", :cyan
        say ""
        say "  3. Add notifiers (Telegram, Slack, etc.)"
        say ""
        say "  4. Visit /faultline to see your error dashboard"
        say ""
        say "=" * 60, :green
      end

      private

      def migration_version
        "[#{ActiveRecord::VERSION::STRING.to_f}]"
      end
    end
  end
end
