describe InvoiceBuilder do
  let(:client) { create(:client, currency: "EUR") }
  let(:project) do
    create(:project, name: "Webshop", client: client, billable: true, hourly_rate: "80", mileage_rate: "0.25")
  end
  let(:dev) { create(:category, name: "Development") }
  let(:design) { create(:category, name: "Design") }

  def build(**options)
    described_class.new(client, issued_on: Date.new(2026, 11, 24), **options).call
  end

  it "groups hours by project and category, snapshots rates and computes tax" do
    hours = [create(:hour, project: project, category: dev, value: 3),
             create(:hour, project: project, category: dev, value: 2),
             create(:hour, project: project, category: design, value: 1)]
    mileage = create(:mileage, project: project, value: 42)

    result = build(hour_ids: hours.map(&:id), mileage_ids: [mileage.id], tax_rate: "21", due_in_days: 30)

    expect(result).to be_success
    invoice = result.invoice
    expect(invoice.lines.map { |l| [l.description, l.quantity.to_i, l.unit_price_cents, l.amount_cents] }).to eq [
      ["Webshop – Design", 1, 8000, 8000],
      ["Webshop – Development", 5, 8000, 40_000],
      ["Webshop – Mileage (km)", 42, 25, 1050]
    ]
    expect([invoice.subtotal_cents, invoice.tax_cents, invoice.total_cents]).to eq [49_050, 10_301, 59_351]
    expect(invoice.currency).to eq "EUR"
    expect(invoice.due_on).to eq Date.new(2026, 12, 24)
    expect(invoice).to be_draft
    expect(hours.map { |h| h.reload.invoice_id }.uniq).to eq [invoice.id]
    expect(hours.all? { |h| h.reload.billed }).to be true

    project.update!(hourly_rate: "999")
    expect(invoice.reload.lines.first.unit_price_cents).to eq 8000
  end

  it "numbers invoices sequentially per year" do
    first = build(hour_ids: [create(:hour, project: project).id]).invoice
    second = build(hour_ids: [create(:hour, project: project).id]).invoice
    next_year = described_class.new(client, issued_on: Date.new(2027, 1, 2),
                                            hour_ids: [create(:hour, project: project).id]).call.invoice

    expect([first.number, second.number, next_year.number]).to eq %w[2026-0001 2026-0002 2027-0001]
  end

  it "refuses entries that are already invoiced, so nothing is billed twice" do
    hour = create(:hour, project: project)
    build(hour_ids: [hour.id])

    result = build(hour_ids: [hour.id])

    expect(result).not_to be_success
    expect(result.errors).to include(I18n.t("invoices.errors.already_billed"))
    expect(Invoice.count).to eq 1
  end

  it "refuses projects without a rate and rolls everything back" do
    project.update!(hourly_rate: nil)
    hour = create(:hour, project: project)

    result = build(hour_ids: [hour.id])

    expect(result.errors).to eq [I18n.t("invoices.errors.missing_hourly_rate", project: "Webshop")]
    expect(Invoice.count).to eq 0
    expect(hour.reload.billed).to be false
  end

  it "refuses entries of another client or a non-billable project" do
    other = create(:project, client: create(:client), billable: true, hourly_rate: "50")
    internal = create(:project, client: client, billable: false, hourly_rate: "50")

    result = build(hour_ids: [create(:hour, project: other).id, create(:hour, project: internal).id])

    expect(result.errors).to include(I18n.t("invoices.errors.wrong_client", project: other.name),
                                     I18n.t("invoices.errors.wrong_client", project: internal.name))
  end

  it "needs at least one entry" do
    expect(build.errors).to eq [I18n.t("invoices.errors.no_entries")]
  end
end
