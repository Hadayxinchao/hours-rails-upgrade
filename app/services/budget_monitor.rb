# Checks a project's budgets and reports thresholds as they are reached.
#
# - Each (kind, threshold) is recorded in budget_alerts and reported once. The
#   insert relies on the unique index, so when two checks race only the one
#   that actually inserted the row sends the email.
# - If several thresholds are passed at once (e.g. a big entry from 70% to
#   105%), one email goes out, for the highest.
# - When usage drops back below a threshold (budget raised, entry deleted), its
#   record is removed so the alert can fire again later.
class BudgetMonitor
  def initialize(project)
    @project = project
  end

  # notify: false records the current state without emailing (demo data).
  def call(notify: true)
    usages = BudgetUsage.for(@project)
    BudgetAlert::KINDS.each do |kind|
      usage = usages.find { |u| u.kind == kind }
      reached = usage ? usage.reached_thresholds : []
      @project.budget_alerts.where(kind: kind).where.not(threshold: reached).delete_all
      next if reached.empty?

      inserted = record(kind, reached)
      notify(usage, inserted.max) if notify && inserted.any?
    end
  end

  private

  def record(kind, thresholds)
    now = Time.current
    rows = thresholds.map do |threshold|
      { project_id: @project.id, kind: kind, threshold: threshold, created_at: now, updated_at: now }
    end
    BudgetAlert.insert_all(rows, unique_by: %i[project_id kind threshold], returning: :threshold)
               .rows.flatten
  end

  def notify(usage, threshold)
    BudgetMailer.threshold_reached(@project, usage.kind, threshold).deliver_later
  end
end
