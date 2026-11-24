describe BroadcastActivityJob do
  include ActionCable::TestHelper
  include Turbo::Broadcastable::TestHelper

  it "renders the entry from its own account even though jobs start in the public schema" do
    Apartment::Tenant.create("acme")
    hour = Apartment::Tenant.switch("acme") do
      create(:hour, user: create(:user, first_name: "Alice"), value: 2)
    end
    # Same ids in the public schema: the wrong-schema lookup would find "Mallory".
    create(:hour, user: create(:user, first_name: "Mallory")) until Hour.maximum(:id).to_i >= hour.id
    User.where(id: hour.user_id).update_all(first_name: "Mallory")

    streams = capture_turbo_stream_broadcasts(BroadcastActivityJob.stream("acme")) do
      perform_enqueued_jobs { Apartment::Tenant.switch("acme") { BroadcastActivityJob.perform_later(hour) } }
    end

    expect(streams.size).to eq 1
    expect(streams.first["action"]).to eq "prepend"
    expect(streams.first["target"]).to eq "activity-feed-list"
    expect(streams.first.to_html).to include("Alice").and(include("2 hours"))
    expect(streams.first.to_html).not_to include("Mallory")
  end

  it "is enqueued when an hours entry is created" do
    expect { create(:hour) }.to have_enqueued_job(BroadcastActivityJob)
  end
end
