feature "API tokens and integrations" do
  let(:subdomain) { generate(:subdomain) }
  let(:owner) { build(:user) }

  before do
    create(:account_with_schema, subdomain: subdomain, owner: owner)
    sign_in_user(owner, subdomain: subdomain)
  end

  scenario "creates a token that is shown once, then revokes it" do
    visit api_tokens_url(subdomain: subdomain)
    fill_in "api_token_name", with: "Laptop CLI"
    click_button I18n.t("api_tokens.create")

    token = find("#new-api-token").text
    expect(token).to start_with("hrs_")
    expect(ApiToken.authenticate(token).name).to eq "Laptop CLI"

    visit api_tokens_url(subdomain: subdomain)
    expect(page).to have_no_content(token)
    expect(page).to have_content(token.first(8))

    click_button I18n.t("api_tokens.revoke")
    expect(page).to have_content I18n.t("api_tokens.revoked")
    expect(ApiToken.authenticate(token)).to be_nil
  end

  scenario "owner adds a webhook; internal addresses are refused" do
    visit integrations_url(subdomain: subdomain)
    fill_in "webhook_endpoint_url", with: "https://169.254.169.254/latest"
    click_button I18n.t("integrations.webhooks.add")
    expect(page).to have_content "Url points to a private or reserved address"

    fill_in "webhook_endpoint_url", with: "https://hooks.example.com/hours"
    uncheck "webhook_event_hour_deleted"
    click_button I18n.t("integrations.webhooks.add")

    expect(page).to have_content I18n.t("integrations.webhooks.created")
    expect(WebhookEndpoint.last.events).to eq %w[hour.created hour.updated invoice.sent invoice.paid]
  end

  scenario "owner connects a Slack workspace" do
    visit integrations_url(subdomain: subdomain)
    expect(page).to have_content "/integrations/slack/commands"
    fill_in "slack_workspace_team_id", with: "t0acme01"
    click_button I18n.t("integrations.slack.connect")

    expect(page).to have_content I18n.t("integrations.slack.connected")
    expect(SlackWorkspace.find_by(subdomain: subdomain).team_id).to eq "T0ACME01"
  end

  scenario "other users can't open the integrations page" do
    member = Apartment::Tenant.switch(subdomain) { create(:user) }
    click_link I18n.t("sign_out")
    sign_in_user(member, subdomain: subdomain)

    expect { visit integrations_url(subdomain: subdomain) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
