# Real concurrent transactions (one connection per thread), so this example
# runs without the wrapping test transaction (js: true → deletion strategy).
describe "Invoice numbering under concurrency", js: true do
  it "gives concurrent invoices distinct, gap-free numbers" do
    client = create(:client)
    project = create(:project, client: client, billable: true, hourly_rate: "10")
    # Pool size is 5 and the example itself holds one connection.
    hour_ids = Array.new(4) { create(:hour, project: project).id }

    ready = Queue.new
    go = Queue.new
    threads = hour_ids.map do |id|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          go.pop
          InvoiceBuilder.new(client, hour_ids: [id], issued_on: Date.new(2026, 11, 24)).call
        end
      end
    end
    hour_ids.size.times { ready.pop }
    hour_ids.size.times { go << true }
    results = threads.map(&:value)

    expect(results).to all(be_success)
    expect(Invoice.pluck(:number).sort).to eq((1..4).map { |n| format("2026-%04d", n) })
  end
end
