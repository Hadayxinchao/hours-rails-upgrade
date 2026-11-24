# How much of one of a project's budgets (hours or amount) is used.
class BudgetUsage
  attr_reader :kind, :used, :limit

  def initialize(kind, used:, limit:)
    @kind = kind
    @used = used
    @limit = limit
  end

  def self.for(project)
    usages = []
    usages << new("hours", used: project.total_hours_spent, limit: project.budget) if project.budget.to_i.positive?
    if project.budget_amount_cents.to_i.positive? && (spent = project.spent_cents)
      usages << new("amount", used: spent, limit: project.budget_amount_cents)
    end
    usages
  end

  def percentage
    (BigDecimal(used.to_s) * 100 / limit).round(1).to_f
  end

  def remaining
    limit - used
  end

  # nil below 80%, then "warning" and "over".
  def level
    return "over" if percentage >= 100
    return "warning" if percentage >= 80

    nil
  end

  def reached_thresholds
    BudgetAlert::THRESHOLDS.select { |threshold| percentage >= threshold }
  end
end
