# Mailer deliver_later jobs (Devise confirmation, password reset, invitations)
# must run in the tenant of the user they are about.
class TenantAwareMailDeliveryJob < ActionMailer::MailDeliveryJob
  include TenantAwareJob
end
