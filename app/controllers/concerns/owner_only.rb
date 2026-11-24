# Account settings pages: only the account owner (404 for everyone else, like
# AccountsController#edit).
module OwnerOnly
  extend ActiveSupport::Concern

  included do
    before_action { raise ActiveRecord::RecordNotFound unless Hours.single_tenant_mode? || current_user_owner? }
  end
end
