describe WebhookDeliveryJob do
  include ActiveJob::TestHelper

  let(:subdomain) { generate(:subdomain) }
  let(:url) { "https://hooks.example.com/hours" }

  before do
    create(:account_with_schema, subdomain: subdomain, owner: build(:user))
    allow(Resolv).to receive(:getaddresses).with("hooks.example.com").and_return(["93.184.216.34"])
  end

  def in_account(&block)
    Apartment::Tenant.switch(subdomain, &block)
  end

  let(:endpoint) { in_account { WebhookEndpoint.create!(url: url, events: %w[hour.created invoice.paid]) } }

  it "stores the signing secret encrypted" do
    raw = in_account { WebhookEndpoint.connection.select_value("SELECT secret FROM webhook_endpoints WHERE id = #{endpoint.id}") }
    expect(raw).not_to include(endpoint.secret)
    expect(in_account { endpoint.reload }.secret).to start_with("whsec_")
  end

  it "delivers subscribed events, signed, from the entry's account" do
    endpoint
    stub = stub_request(:post, url).to_return(status: 200)

    hour = perform_enqueued_jobs(only: WebhookDeliveryJob) do
      in_account { create(:hour, description: "Pairing #review") }
    end

    expect(stub).to have_been_requested.once
    request = WebMock::RequestRegistry.instance.requested_signatures.hash.keys.first
    body = JSON.parse(request.body)
    expect(body).to include("event" => "hour.created")
    expect(body["data"]).to include("id" => hour.id, "tags" => ["review"])

    timestamp = request.headers["Hours-Signature"][/t=(\d+)/, 1]
    expected = WebhookDeliveryJob.signature(in_account { endpoint.reload }.secret, timestamp, request.body)
    expect(request.headers["Hours-Signature"]).to eq expected
    expect(request.headers["Hours-Delivery"]).to eq body["id"]
    expect(in_account { endpoint.reload }).to have_attributes(last_status: 200, consecutive_failures: 0)
  end

  it "does not send events the endpoint didn't subscribe to" do
    endpoint
    in_account { expect { create(:hour).destroy }.not_to have_enqueued_job(WebhookDeliveryJob).with(anything, "hour.deleted", anything) }
  end

  it "retries server errors and timeouts, but not other 4xx responses" do
    payload = { id: SecureRandom.uuid, event: "ping", data: {} }.to_json
    stub_request(:post, url).to_return(status: 503)
    in_account do
      expect { WebhookDeliveryJob.perform_now(endpoint.id, "ping", payload) }.to have_enqueued_job(WebhookDeliveryJob)
    end

    stub_request(:post, url).to_timeout
    in_account do
      expect { WebhookDeliveryJob.perform_now(endpoint.id, "ping", payload) }.to have_enqueued_job(WebhookDeliveryJob)
    end

    stub_request(:post, url).to_return(status: 410)
    in_account do
      expect { WebhookDeliveryJob.perform_now(endpoint.id, "ping", payload) }.not_to have_enqueued_job(WebhookDeliveryJob)
    end
    expect(in_account { endpoint.reload }).to have_attributes(last_status: 410, consecutive_failures: 3)
  end

  it "refuses to deliver when the host now resolves to a private address (DNS rebinding)" do
    endpoint
    allow(Resolv).to receive(:getaddresses).with("hooks.example.com").and_return(["169.254.169.254"])
    payload = { id: SecureRandom.uuid, event: "ping", data: {} }.to_json

    in_account { WebhookDeliveryJob.perform_now(endpoint.id, "ping", payload) }

    expect(a_request(:post, url)).not_to have_been_made
    expect(in_account { endpoint.reload }.last_error).to include("private or reserved")
  end

  it "turns an endpoint off after repeated failures" do
    in_account { endpoint.update_columns(consecutive_failures: WebhookEndpoint::DISABLE_AFTER_FAILURES - 1) }
    stub_request(:post, url).to_return(status: 500)

    in_account do
      WebhookDeliveryJob.perform_now(endpoint.id, "ping", { id: SecureRandom.uuid }.to_json)
    end

    expect(in_account { endpoint.reload.active }).to be false
  end
end
