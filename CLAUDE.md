# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About

Faultline is a self-hosted error tracking Rails engine for Rails 8+ applications. It provides automatic error capture, smart grouping, local variable inspection, notifications (Telegram/Slack/Email/Webhook), GitHub integration, and basic APM.

## Commands

```bash
# Install dependencies
bundle install

# Run all tests
bundle exec rspec

# Run a single test file
bundle exec rspec spec/lib/faultline/tracker_spec.rb

# Run a specific test by line number
bundle exec rspec spec/lib/faultline/tracker_spec.rb:25
```

## Architecture

### Rails Engine Structure

This is a mountable Rails engine. Key components:

- **Entry point**: `lib/faultline.rb` - loads all components and provides `Faultline.track()` and `Faultline.configure`
- **Engine**: `lib/faultline/engine.rb` - registers middleware, error subscriber, and APM collector via Rails initializers
- **Routes**: `config/routes.rb` - mounts at `/faultline` with error_groups, error_occurrences, performance, and traces resources

### Error Tracking Flow

```
Exception raised
    ↓
Middleware (lib/faultline/middleware.rb) catches exception
    ↓
TracePoint captures local variables at raise site
    ↓
Tracker (lib/faultline/tracker.rb) creates/updates ErrorGroup and ErrorOccurrence
    ↓
Notifiers called if notification rules match
```

The middleware uses `TracePoint` on `:line` and `:raise` events to capture local variables even when exceptions originate in gem code.

### APM Flow

```
process_action.action_controller (Rails notification)
    ↓
Collector (lib/faultline/apm/collector.rb) subscribes to events
    ↓
SpanCollector captures SQL, view, HTTP, Redis spans
    ↓
RequestTrace stored in database
```

APM is opt-in (`config.enable_apm = true`) and uses `ActiveSupport::Notifications`.

### Models

- `Faultline::ErrorGroup` - grouped errors by fingerprint (class + message + location)
- `Faultline::ErrorOccurrence` - individual error instances with backtrace, request data, local variables
- `Faultline::ErrorContext` - custom key-value context data
- `Faultline::RequestTrace` - APM trace with timing, spans, status
- `Faultline::RequestProfile` - optional Vernier profiler data

### Notifiers

All in `lib/faultline/notifiers/`:
- `Base` - abstract base class with `should_notify?` and `format_message`
- `Telegram`, `Slack`, `Webhook`, `Resend`, `Email` - concrete implementations

### Configuration

All configuration options in `lib/faultline/configuration.rb`. Key options:
- `authenticate_with` - lambda for dashboard auth
- `enable_middleware` - error capture (default: true)
- `enable_apm` - APM tracking (default: false)
- `notification_cooldown` - rate limiting for notifications
- `notification_rules` - when to notify (first occurrence, reopen, thresholds)

## Testing

Tests use RSpec with a dummy Rails app in `spec/dummy/`. FactoryBot factories are in `spec/factories/`.

Request specs are in `spec/requests/`, model specs in `spec/models/`, lib specs in `spec/lib/`.
