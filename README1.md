# Faultline

[![Build](https://img.shields.io/badge/build-passing-brightgreen)](https://github.com/dlt/faultline/actions)
[![Coverage](https://img.shields.io/badge/coverage-82%25-green)](https://github.com/dlt/faultline)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.2-red)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/rails-%3E%3D%208.0-red)](https://rubyonrails.org/)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

**Stop paying for error tracking. Own your data. Debug like you have a debugger attached to production.**

![Faultline Dashboard](faultline.png)

---

## The Problem

You're paying $300/month for Sentry. Your error data—including user info, request params, and stack traces—flows through third-party servers. When something breaks at 2 AM, you're digging through logs because the free tier ran out of events.

**Faultline fixes this.** It's a Rails engine that runs inside your app. No external services. No event limits. No data leaving your infrastructure. And when errors happen, you see the actual variable values at the crash point—like having `binding.pry` in production.

---

## See It In Action

### The Debugger View
When an error occurs, Faultline captures local variables at the exact line where the exception was raised:

```
┌─ Source Code ─────────────────────────┬─ Local Variables ──────────────────┐
│                                       │                                    │
│   45:   def charge_customer           │  user: #<User id: 42>              │
│   46:     amount = calculate_total    │  amount: 99.99                     │
│ → 47:     Stripe.charge(amount)  ━━━━━│  card_token: "tok_visa_declined"   │
│   48:   rescue => e                   │  order: #<Order id: 187>           │
│   49:     raise                       │                                    │
│                                       │                                    │
└───────────────────────────────────────┴────────────────────────────────────┘
```

No more guessing. No more "works on my machine." See exactly what went wrong.

---

## Quick Start

```bash
# Add to Gemfile
gem "faultline", git: "https://github.com/dlt/faultline.git"

# Install
bundle install
rails generate faultline:install
rails db:migrate

# Done! Visit /faultline in your app
```

That's it. Errors are now being captured with full context.

---

## Why Teams Choose Faultline

| | Faultline | Sentry/Honeybadger |
|---|---|---|
| **Cost** | Free forever | $26-300+/month |
| **Data location** | Your servers | Their servers |
| **Event limits** | Unlimited | 5K-100K/month |
| **Local variables** | Always captured | Paid plans only |
| **Setup time** | 5 minutes | 5 minutes |

### Perfect For

- **Privacy-conscious teams** — GDPR, HIPAA, or just "our data stays with us"
- **Bootstrapped startups** — Stop paying SaaS taxes before you have revenue
- **Enterprise Rails apps** — No vendor approval needed, runs in your VPC
- **Side projects** — Production-grade error tracking without the production-grade bill

---

## Features

### Automatic Error Capture
Every unhandled exception is captured automatically via Rack middleware. Background job errors are captured via the Rails error reporting API. Zero configuration required.

### Local Variable Capture
When an exception is raised, Faultline uses Ruby's TracePoint to snapshot all local variables. Sensitive data (passwords, tokens, API keys) is automatically filtered.

### Smart Error Grouping
Errors are grouped by fingerprint (exception class + sanitized message + location). See one entry for "User not found" instead of 500 duplicates.

### Auto-Reopen Detection
Marked an error as resolved? If it happens again, Faultline automatically reopens it and notifies you. No more "I thought we fixed that."

### Full-Text Search
Search across exception classes, messages, and file paths. Find that obscure error from last Tuesday in seconds.

### GitHub Integration
Create GitHub issues directly from errors. The issue includes the stack trace, local variables, request context, and source code snippet—everything needed to debug.

### Notification Channels
Get alerted via Slack, Telegram, email (Resend), or custom webhooks. Rate limiting prevents notification storms during outages.

### Clean Dashboard
A Tailwind-powered UI with filtering, sorting, bulk actions, and interactive charts. No JavaScript framework bloat.

---

## Configuration

### Protect Your Dashboard (Required for Production)

```ruby
# config/initializers/faultline.rb
Faultline.configure do |config|
  # Only allow admin users
  config.authenticate_with = ->(request) {
    request.env["warden"]&.user&.admin?
  }
end
```

### Enable Notifications (Optional)

Faultline tracks errors regardless of notification setup. Add notifiers only if you want alerts:

```ruby
# Slack
config.add_notifier Faultline::Notifiers::Slack.new(
  webhook_url: Rails.application.credentials.dig(:faultline, :slack, :webhook_url)
)

# Telegram
config.add_notifier Faultline::Notifiers::Telegram.new(
  bot_token: Rails.application.credentials.dig(:faultline, :telegram, :bot_token),
  chat_id: Rails.application.credentials.dig(:faultline, :telegram, :chat_id)
)

# Email via Resend
config.add_notifier Faultline::Notifiers::Resend.new(
  api_key: Rails.application.credentials.dig(:faultline, :resend, :api_key),
  from: "errors@yourapp.com",
  to: ["dev@yourapp.com", "ops@yourapp.com"]
)
```

### GitHub Issues

```ruby
config.github_repo = "your-org/your-repo"
config.github_token = Rails.application.credentials.dig(:faultline, :github, :token)
config.github_labels = ["bug", "faultline"]
```

### Control What Gets Tracked

```ruby
# Ignore common noise
config.ignored_exceptions = [
  "ActiveRecord::RecordNotFound",
  "ActionController::RoutingError"
]

# Ignore bots
config.ignored_user_agents = [/bot/i, /crawler/i, /Googlebot/i]

# Ignore health checks
config.middleware_ignore_paths = ["/health", "/up"]
```

### Add Custom Context

```ruby
# Include app-specific data with every error
config.custom_context = ->(request, env) {
  controller = env["action_controller.instance"]
  {
    account_id: controller&.current_account&.id,
    plan: controller&.current_account&.plan,
    feature_flags: controller&.enabled_features
  }
}
```

### Notification Rules

```ruby
config.notification_rules = {
  on_first_occurrence: true,        # Alert on new error types
  on_reopen: true,                  # Alert when resolved errors recur
  on_threshold: [10, 50, 100],      # Alert at these counts
  critical_exceptions: [            # Always alert for these
    "Stripe::APIError",
    "ActiveRecord::StatementInvalid"
  ],
  notify_in_environments: ["production"]
}

config.notification_cooldown = 5.minutes  # Prevent spam during outages
```

---

## Advanced Usage

### Manual Tracking

```ruby
begin
  risky_operation
rescue => e
  Faultline.track(e, {
    request: request,
    user: current_user,
    custom_data: { order_id: @order.id }
  })
  raise  # Re-raise after tracking
end
```

### Callbacks

```ruby
# Skip certain errors
config.before_track = ->(exception, context) {
  return false if exception.message.include?("Timeout")
  true
}

# Integrate with other services
config.after_track = ->(error_group, occurrence) {
  Analytics.track("error_occurred", {
    type: error_group.exception_class,
    count: error_group.occurrences_count
  })
}
```

### Custom Fingerprinting

```ruby
# Group errors by tenant
config.custom_fingerprint = ->(exception, context) {
  { extra_components: [context.dig(:custom_data, :tenant_id)] }
}
```

### Custom Notifiers

```ruby
class PagerDutyNotifier < Faultline::Notifiers::Base
  def initialize(api_key:)
    @api_key = api_key
  end

  def call(error_group, occurrence)
    data = format_message(error_group, occurrence)
    PagerDuty.trigger(data, routing_key: @api_key)
  end

  def should_notify?(error_group, occurrence)
    error_group.occurrences_count == 1  # Only page on first occurrence
  end
end

config.add_notifier PagerDutyNotifier.new(api_key: "...")
```

---

## Data & Retention

### Database Tables

Faultline creates three tables:
- `faultline_error_groups` — Unique errors grouped by fingerprint
- `faultline_error_occurrences` — Individual error instances with full context
- `faultline_error_contexts` — Custom key-value data per occurrence

### Cleanup

```ruby
config.retention_days = 90  # Set to nil to keep forever

# Add to your scheduler (cron, Sidekiq, etc.)
Faultline::ErrorOccurrence
  .where("created_at < ?", 90.days.ago)
  .in_batches
  .delete_all
```

---

## Requirements

- Ruby 3.2+
- Rails 8.0+
- PostgreSQL, MySQL, or SQLite

---

## Comparison with Alternatives

| Feature | Faultline | Solid Errors | Sentry | Honeybadger |
|---------|-----------|--------------|--------|-------------|
| Self-hosted | Yes | Yes | Paid | No |
| Local variables | Yes | No | Paid | Paid |
| Error grouping | Yes | No | Yes | Yes |
| Notifications | Yes | No | Yes | Yes |
| GitHub integration | Yes | No | Yes | Yes |
| Full-text search | Yes | No | Yes | Yes |
| Cost | Free | Free | $26+/mo | $49+/mo |

**What Faultline doesn't do:** JavaScript source maps, APM/performance monitoring, mobile SDKs. It's focused on being excellent at Rails error tracking, not being everything to everyone.

---

## Contributing

We welcome contributions! Here's how to get started:

```bash
git clone https://github.com/dlt/faultline.git
cd faultline
bundle install
bundle exec rspec
```

- Check out [open issues](https://github.com/dlt/faultline/issues)
- Read our contributing guidelines (coming soon)
- Join the discussion in GitHub Discussions

---

## License

MIT License. Use it, fork it, sell it, whatever. See [LICENSE](LICENSE) for details.

---

<p align="center">
  <b>Built for Rails developers who value simplicity, privacy, and not paying per error.</b>
  <br><br>
  <a href="https://github.com/dlt/faultline">Star on GitHub</a> ·
  <a href="https://github.com/dlt/faultline/issues">Report Bug</a> ·
  <a href="https://github.com/dlt/faultline/issues">Request Feature</a>
</p>
