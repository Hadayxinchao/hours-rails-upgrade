class ApplicationJob < ActiveJob::Base
  include TenantAwareJob
end
