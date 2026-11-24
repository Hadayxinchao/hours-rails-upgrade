module InvoicesHelper
  def money(cents, currency)
    cents.nil? ? "–" : Money.format(cents, currency)
  end

  def budget_label(usage, currency)
    if usage.kind == "hours"
      t("budget_status.hours", used: usage.used, limit: usage.limit)
    else
      t("budget_status.amount", used: money(usage.used, currency), limit: money(usage.limit, currency))
    end
  end

  def invoice_status_badge(invoice)
    status = invoice.display_status
    content_tag(:span, t("invoices.statuses.#{status}"), class: "invoice-status invoice-status--#{status}")
  end

  # Unbilled entries per client with their value at current rates; nil when a
  # project has entries but no rate yet.
  def unbilled_by_client(projects, hours_by_project, mileages_by_project)
    projects.group_by(&:client).sort_by { |client, _| client.name.downcase }.map do |client, client_projects|
      hours = client_projects.sum { |p| Array(hours_by_project[p.id]).sum(&:value) }
      amount = client_projects.sum do |p|
        h = Array(hours_by_project[p.id]).sum(&:value)
        m = Array(mileages_by_project[p.id]).sum(&:value)
        break nil if (h.positive? && !p.hourly_rate_cents) || (m.positive? && !p.mileage_rate_cents)

        h * p.hourly_rate_cents.to_i + m * p.mileage_rate_cents.to_i
      end
      { client: client, hours: hours, amount_cents: amount }
    end
  end
end
