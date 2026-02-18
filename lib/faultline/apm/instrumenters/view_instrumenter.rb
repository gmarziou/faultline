# frozen_string_literal: true

module Faultline
  module Apm
    module Instrumenters
      class ViewInstrumenter
        EVENTS = %w[
          render_template.action_view
          render_partial.action_view
          render_collection.action_view
        ].freeze

        class << self
          def start!
            return if @subscribers&.any?

            @subscribers = EVENTS.map do |event_name|
              ActiveSupport::Notifications.subscribe(event_name) do |*args|
                event = ActiveSupport::Notifications::Event.new(*args)
                process_event(event)
              end
            end
          end

          def stop!
            @subscribers&.each do |subscriber|
              ActiveSupport::Notifications.unsubscribe(subscriber)
            end
            @subscribers = nil
          end

          private

          def process_event(event)
            return unless SpanCollector.active?

            payload = event.payload
            identifier = payload[:identifier] || payload[:virtual_path] || "unknown"

            # Extract relative path from full path
            description = if identifier.include?(Rails.root.to_s)
                            identifier.sub("#{Rails.root}/", "")
                          else
                            identifier
                          end

            # Determine view type
            view_type = case event.name
                        when "render_partial.action_view"
                          "partial"
                        when "render_collection.action_view"
                          "collection"
                        else
                          "template"
                        end

            SpanCollector.record_span(
              type: :view,
              description: description,
              duration_ms: event.duration,
              metadata: {
                view_type: view_type,
                layout: payload[:layout],
                count: payload[:count]
              }.compact
            )
          end
        end
      end
    end
  end
end
