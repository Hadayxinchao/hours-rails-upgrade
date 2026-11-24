# WebSocket connections are tenant-aware like requests are. A connection is
# opened outside any controller, so Apartment is still on the public schema:
# looking the signed-in user up there would find nobody, or another account's
# user with the same id. The account is resolved from the subdomain and the
# Warden user is loaded inside that tenant.
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :tenant

    def connect
      self.tenant = find_tenant
      self.current_user = Apartment::Tenant.switch(tenant) { env["warden"]&.user } ||
                          reject_unauthorized_connection
    end

    private

    def find_tenant
      return Apartment.default_tenant if Hours.single_tenant_mode?

      subdomain = request.subdomain
      reject_unauthorized_connection unless subdomain.present? && Account.exists?(subdomain: subdomain)
      subdomain
    end
  end
end
