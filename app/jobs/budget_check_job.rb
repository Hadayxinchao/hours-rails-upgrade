# Runs BudgetMonitor after hours, mileage or a project's budget/rates change.
# Tenant-aware (ApplicationJob), so it reads the right account's project.
class BudgetCheckJob < ApplicationJob
  discard_on ActiveJob::DeserializationError # project deleted meanwhile

  def perform(project)
    BudgetMonitor.new(project).call
  end
end
