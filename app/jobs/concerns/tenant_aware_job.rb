# Runs a job in the Apartment tenant (schema) it was enqueued from.
#
# Jobs execute outside any request, so without this a job would look up its
# records (e.g. the User a Devise email is for) in the default schema and
# either fail or, worse, find another account's row with the same id.
#
# The switch wraps the whole of perform_now, because Active Job deserializes
# GlobalID arguments before perform callbacks run.
module TenantAwareJob
  extend ActiveSupport::Concern

  included do
    attr_accessor :tenant
  end

  def initialize(...)
    super
    @tenant = Apartment::Tenant.current
  end

  def serialize
    super.merge("tenant" => tenant)
  end

  def deserialize(job_data)
    super
    self.tenant = job_data["tenant"]
  end

  def perform_now
    Apartment::Tenant.switch(tenant.presence || Apartment.default_tenant) { super }
  end
end
