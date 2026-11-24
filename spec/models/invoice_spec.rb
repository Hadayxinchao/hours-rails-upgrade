describe Invoice do
  let(:client) { create(:client) }
  let(:project) { create(:project, client: client, billable: true, hourly_rate: "100") }
  let!(:hour) { create(:hour, project: project, value: 2) }
  let(:invoice) do
    InvoiceBuilder.new(client, hour_ids: [hour.id], issued_on: Date.new(2026, 11, 1), due_in_days: 14).call.invoice
  end

  it "moves draft → sent → paid" do
    invoice.mark_sent!
    expect(invoice).to be_sent
    expect(invoice.sent_at).to be_present
    invoice.mark_paid!
    expect(invoice).to be_paid
  end

  it "refuses invalid transitions" do
    expect { invoice.mark_paid! }.to raise_error(Invoice::InvalidTransition)
    invoice.mark_sent!
    expect { invoice.destroy_draft! }.to raise_error(Invoice::InvalidTransition)
  end

  it "is overdue when sent and past its due date" do
    invoice.mark_sent!
    expect(invoice.display_status(Date.new(2026, 11, 15))).to eq "sent"
    expect(invoice.display_status(Date.new(2026, 11, 16))).to eq "overdue"
  end

  it "voiding keeps the number and releases the entries" do
    invoice.mark_sent!
    invoice.void!

    expect(invoice.reload).to be_void
    expect(invoice.number).to eq "2026-0001"
    expect(hour.reload).to have_attributes(invoice_id: nil, billed: false)
  end

  it "deleting a draft releases the entries" do
    invoice.destroy_draft!

    expect(Invoice.count).to eq 0
    expect(InvoiceLine.count).to eq 0
    expect(hour.reload).to have_attributes(invoice_id: nil, billed: false)
  end

  describe "invoiced entries" do
    before { invoice }

    it "can't have their hours, date or project changed" do
      hour.reload
      expect(hour.update(value: 5)).to be false
      expect(hour.errors[:base].first).to include(invoice.number)
      expect(hour.reload.update(description: "clarified #note")).to be true
    end

    it "can't be deleted" do
      expect(hour.reload.destroy).to be false
      expect(Hour.exists?(hour.id)).to be true
    end
  end
end
