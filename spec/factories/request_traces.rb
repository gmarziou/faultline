# frozen_string_literal: true

FactoryBot.define do
  factory :request_trace, class: "Faultline::RequestTrace" do
    sequence(:endpoint) { |n| "UsersController#action_#{n}" }
    http_method { "GET" }
    path { "/users" }
    status { 200 }
    duration_ms { rand(10.0..500.0).round(2) }
    db_runtime_ms { rand(1.0..50.0).round(2) }
    view_runtime_ms { rand(5.0..200.0).round(2) }
    db_query_count { rand(1..20) }
    created_at { Time.current }

    trait :slow do
      duration_ms { rand(500.0..2000.0).round(2) }
    end

    trait :error do
      status { 500 }
    end

    trait :post_request do
      http_method { "POST" }
    end

    trait :old do
      created_at { 35.days.ago }
    end
  end
end
