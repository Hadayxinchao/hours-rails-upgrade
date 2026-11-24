# "Project X has used 80% / 100% of its hours or amount budget." Sent through
# deliver_later, which runs in the account's schema (TenantAwareMailDeliveryJob).
class BudgetMailer < ApplicationMailer
  helper InvoicesHelper

  def threshold_reached(project, kind, threshold)
    @project = project
    @usage = project.budget_usages.find { |usage| usage.kind == kind }
    @threshold = threshold
    return if @usage.nil? || recipients.empty? # budget removed before the email ran

    mail to: recipients,
         subject: t("budget_mailer.subject.#{threshold == 100 ? 'over' : 'warning'}",
                    project: project.name, percent: @usage.percentage.round,
                    budget: t("budget_mailer.kinds.#{kind}"))
  end

  private

  # The account owner; every user in single-tenant mode, which has no owner.
  def recipients
    @recipients ||= if Hours.single_tenant_mode?
                      User.pluck(:email)
                    else
                      Array(Account.find_by(subdomain: Apartment::Tenant.current)&.owner&.email)
                    end
  end
end
