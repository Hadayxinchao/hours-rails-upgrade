# Builds a draft invoice for one client from selected unbilled entries.
#
#   result = InvoiceBuilder.new(client, hour_ids: [...], mileage_ids: [...],
#                               issued_on: Date.current, due_in_days: 14, tax_rate: 21).call
#   result.invoice  # persisted draft, or nil
#   result.errors   # why it could not be built
#
# Entries are locked FOR UPDATE and re-checked inside the transaction, so the
# same entry can never end up on two invoices, even with concurrent requests.
class InvoiceBuilder
  Result = Struct.new(:invoice, :errors) do
    def success?
      errors.empty?
    end
  end

  def initialize(client, hour_ids: [], mileage_ids: [], issued_on: Date.current, due_in_days: 14,
                 tax_rate: 0, notes: nil)
    @client = client
    @hour_ids = Array(hour_ids).compact_blank.map(&:to_i)
    @mileage_ids = Array(mileage_ids).compact_blank.map(&:to_i)
    @issued_on = issued_on
    @due_in_days = due_in_days.to_i
    @tax_rate = tax_rate.presence || 0
    @notes = notes
  end

  def call
    return Result.new(nil, [I18n.t("invoices.errors.no_entries")]) if @hour_ids.empty? && @mileage_ids.empty?

    errors = []
    invoice = nil
    Invoice.transaction do
      hours = lock(Hour.includes(:category, :project), @hour_ids)
      mileages = lock(Mileage.includes(:project), @mileage_ids)
      errors = check(hours, mileages)
      raise ActiveRecord::Rollback if errors.any?

      invoice = build_invoice(hours, mileages)
      unless invoice.save
        errors = invoice.errors.full_messages
        raise ActiveRecord::Rollback
      end
      { Hour => hours, Mileage => mileages }.each do |model, entries|
        model.where(id: entries.map(&:id))
             .update_all(invoice_id: invoice.id, billed: true, updated_at: Time.current)
      end
    end
    errors.any? ? Result.new(nil, errors) : Result.new(invoice, [])
  end

  private

  def lock(scope, ids)
    return [] if ids.empty?

    scope.where(id: ids).order(:id).lock.to_a
  end

  def check(hours, mileages)
    errors = []
    found = hours.size + mileages.size
    errors << I18n.t("invoices.errors.entries_changed") if found != @hour_ids.size + @mileage_ids.size
    (hours + mileages).each do |entry|
      project = entry.project
      if project.client_id != @client.id || !project.billable
        errors << I18n.t("invoices.errors.wrong_client", project: project.name)
      elsif entry.billed || entry.invoice_id
        errors << I18n.t("invoices.errors.already_billed")
      end
    end
    hours.map(&:project).uniq.reject(&:hourly_rate_cents).each do |project|
      errors << I18n.t("invoices.errors.missing_hourly_rate", project: project.name)
    end
    mileages.map(&:project).uniq.reject(&:mileage_rate_cents).each do |project|
      errors << I18n.t("invoices.errors.missing_mileage_rate", project: project.name)
    end
    errors.uniq
  end

  def build_invoice(hours, mileages)
    invoice = Invoice.new(client: @client, currency: @client.currency, status: "draft",
                          number: Invoice.next_number(@issued_on.year), issued_on: @issued_on,
                          due_on: @issued_on + @due_in_days, tax_rate: @tax_rate, notes: @notes)
    (hour_lines(hours) + mileage_lines(mileages)).each_with_index do |attrs, position|
      invoice.lines.build(**attrs, position: position)
    end
    invoice.recalculate_totals
    invoice
  end

  def hour_lines(hours)
    groups = hours.group_by { |hour| [hour.project, hour.category] }
    groups.sort_by { |(project, category), _| [project.name.downcase, category.name.downcase] }
          .map do |(project, category), entries|
      line(project, "hours", "#{project.name} – #{category.name}", entries.sum(&:value),
           project.hourly_rate_cents)
    end
  end

  def mileage_lines(mileages)
    mileages.group_by(&:project).sort_by { |project, _| project.name.downcase }.map do |project, entries|
      line(project, "mileage", "#{project.name} – #{I18n.t('invoices.mileage_line')}",
           entries.sum(&:value), project.mileage_rate_cents)
    end
  end

  def line(project, kind, description, quantity, unit_price_cents)
    { project: project, kind: kind, description: description, quantity: quantity,
      unit_price_cents: unit_price_cents, amount_cents: quantity * unit_price_cents }
  end
end
