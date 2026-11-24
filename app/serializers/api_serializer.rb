# JSON shapes of the v1 API. Kept in one place so docs/api/openapi.yaml and the
# response-validation specs have one thing to match.
module ApiSerializer
  module_function

  def user(user)
    { id: user.id, first_name: user.first_name, last_name: user.last_name, email: user.email }
  end

  def project(project)
    {
      id: project.id, slug: project.slug, name: project.name, billable: project.billable,
      archived: project.archived, client: project.client && { id: project.client.id, name: project.client.name },
      currency: project.money_currency,
      hourly_rate: decimal(project.hourly_rate),
      budgets: project.budget_usages.map do |usage|
        { kind: usage.kind, used: usage.kind == "amount" ? money(usage.used, project) : usage.used,
          limit: usage.kind == "amount" ? money(usage.limit, project) : usage.limit,
          percentage: usage.percentage, level: usage.level }
      end
    }
  end

  def category(category)
    { id: category.id, name: category.name }
  end

  def hour(hour)
    {
      id: hour.id, date: hour.date.iso8601, hours: hour.value, description: hour.description.to_s,
      project_id: hour.project_id, category_id: hour.category_id, user_id: hour.user_id,
      billed: hour.billed, invoice_id: hour.invoice_id,
      tags: hour.tags.map(&:name),
      created_at: hour.created_at.iso8601, updated_at: hour.updated_at.iso8601
    }
  end

  def timer(timer)
    {
      project_id: timer.project_id, category_id: timer.category_id, description: timer.description.to_s,
      started_at: timer.started_at.iso8601, elapsed_seconds: timer.elapsed.to_i
    }
  end

  def decimal(value)
    value&.to_s("F")
  end

  def money(cents, project)
    Money.to_input(cents, project.money_currency)
  end
end
