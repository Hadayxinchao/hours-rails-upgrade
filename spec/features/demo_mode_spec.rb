feature "Public demo mode" do
  before do
    allow(Hours).to receive(:demo_mode?).and_return(true)
    DemoAccount.reset!
  end

  let(:subdomain) { DemoAccount::SUBDOMAIN }

  scenario "the sign-in page offers the demo login, which works" do
    visit new_user_session_url(subdomain: subdomain)
    expect(page).to have_content(DemoAccount::EMAIL)
    expect(find_field(I18n.t("account.email")).value).to eq DemoAccount::EMAIL

    click_button I18n.t("sign_in")
    expect(page).to have_content(I18n.t("devise.sessions.signed_in"))
  end

  scenario "the demo account cannot be deleted" do
    visit new_user_session_url(subdomain: subdomain)
    click_button I18n.t("sign_in")
    visit edit_account_url(subdomain: subdomain)

    click_button "Delete my account"

    expect(page).to have_content(I18n.t("demo.disabled"))
    expect(Account.exists?(subdomain: subdomain)).to be true
  end

  scenario "the demo login's password cannot be changed" do
    visit new_user_session_url(subdomain: subdomain)
    click_button I18n.t("sign_in")
    visit edit_user_url(subdomain: subdomain)

    fill_in "user_password", with: "taken-over"
    fill_in "user_password_confirmation", with: "taken-over"
    fill_in "user_current_password", with: DemoAccount::PASSWORD
    click_button I18n.t("registration.update_button")

    expect(page).to have_content(I18n.t("demo.disabled"))
    Apartment::Tenant.switch(subdomain) do
      expect(User.find_by!(email: DemoAccount::EMAIL).valid_password?(DemoAccount::PASSWORD)).to be true
    end
  end

  scenario "webhooks and Slack can't be set up from the public demo" do
    visit new_user_session_url(subdomain: subdomain)
    click_button I18n.t("sign_in")
    visit integrations_url(subdomain: subdomain)
    fill_in "webhook_endpoint_url", with: "https://hooks.example.com/x"
    click_button I18n.t("integrations.webhooks.add")

    expect(page).to have_content(I18n.t("demo.disabled"))
    expect(Apartment::Tenant.switch(subdomain) { WebhookEndpoint.count }).to eq 0
  end

  scenario "outside demo mode the sign-in page shows no demo login" do
    allow(Hours).to receive(:demo_mode?).and_return(false)
    visit new_user_session_url(subdomain: subdomain)
    expect(page).to have_no_content(DemoAccount::EMAIL)
  end
end
