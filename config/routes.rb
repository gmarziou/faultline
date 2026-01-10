# frozen_string_literal: true

Faultline::Engine.routes.draw do
  root to: "error_groups#index"

  resources :error_groups do
    member do
      patch :resolve
      patch :unresolve
      patch :ignore
    end

    collection do
      post :bulk_action
    end
  end

  resources :error_occurrences, only: [:index, :show]
end
