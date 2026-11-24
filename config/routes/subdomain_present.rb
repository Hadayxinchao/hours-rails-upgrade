devise_for :users, controllers: { registrations: "users/registrations" }
resources :archives, only: [:index]
resources :projects, only: %i[index edit new update create show] do
  resources :audits, only: [:index]
end
resources :categories, only: %i[index create edit update]
resources :entries, only: [:index]

resources :hours, :mileages, only: %i[create destroy update edit] do
  resources :audits, only: [:index]
end

resources :reports, only: [:index]

resources :billables, only: [:index]

resources :api_tokens, only: %i[index create destroy]
resource :integrations, only: [:show]
resources :webhook_endpoints, only: %i[create destroy] do
  post :ping, on: :member
end
resource :slack_workspace, only: %i[create destroy]
get "integrations/slack/link" => "slack_links#show", as: :slack_link
post "integrations/slack/link" => "slack_links#create"

namespace :api, defaults: { format: :json } do
  namespace :v1 do
    get "me" => "me#show"
    resources :projects, only: %i[index show]
    resources :categories, only: [:index]
    resources :hours, only: %i[index show create update destroy]
    resource :timer, only: %i[show create destroy] do
      post :stop
    end
  end
end
get "api/v1/openapi.yaml" => "api_docs#show", as: :api_openapi

resource :timer, only: %i[create destroy] do
  post :stop
end

resources :invoices, only: %i[index new create show destroy] do
  member do
    patch :mark_sent
    patch :mark_paid
    patch :void
  end
end

resources :users, only: %i[index update show] do
  resources :entries, only: [:index]
end

resources :tags, only: [:show]
resources :clients, only: %i[show index edit update create]

get "user/edit" => "users#edit", as: :edit_user
get "account/edit" => "accounts#edit", as: :edit_account
delete "account" => "accounts#destroy", as: :destroy_account
post "billables" => "billables#bill_entries", as: :bill_entries
