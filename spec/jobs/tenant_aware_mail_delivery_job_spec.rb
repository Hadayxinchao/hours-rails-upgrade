describe TenantAwareMailDeliveryJob do
  include ActiveJob::TestHelper

  it "is the delivery job for deliver_later" do
    expect(ActionMailer::Base.delivery_job).to eq(described_class)
  end

  it "delivers a Devise email from a worker that is in another tenant" do
    account = create(:account_with_schema, subdomain: "tenant-a")
    Apartment::Tenant.switch!(account.subdomain)
    user = create(:user, email: "tenant-a-user@example.com")

    expect { user.send_reset_password_instructions }
      .to have_enqueued_job(described_class)
    job = enqueued_jobs.last
    expect(job["tenant"]).to eq("tenant-a")

    # The worker is not in the user's schema: without the tenant switch the
    # GlobalID lookup for the user would fail here.
    Apartment::Tenant.reset
    expect { perform_enqueued_jobs }
      .to change { ActionMailer::Base.deliveries.count }.by(1)
    expect(ActionMailer::Base.deliveries.last.to).to eq(["tenant-a-user@example.com"])
  end
end
