class ApplicationMailer < ActionMailer::Base
  default from: -> { Devise.mailer_sender } # info@<SMTP domain> in production
  helper EmailHelper
end
