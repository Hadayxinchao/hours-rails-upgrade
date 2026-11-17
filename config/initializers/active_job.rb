# deliver_later must run in the tenant that enqueued the email.
Rails.application.config.to_prepare do
  ActionMailer::Base.delivery_job = TenantAwareMailDeliveryJob
end
