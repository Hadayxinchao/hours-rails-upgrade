feature "Downloading enries" do
  let(:subdomain) { generate(:subdomain) }
  let(:user) { build(:user) }
  let(:entry) { create(:entry, user: user) }

  before(:each) do
    create(:account_with_schema, subdomain: subdomain, owner: user)
    sign_in_user(user, subdomain: subdomain)
  end

  scenario "download CSV through My Entries" do
    visit user_entries_url(user, subdomain: subdomain)
    click_link I18n.t("entries.download_csv")

    content_disposition = page.response_headers["Content-Disposition"]
    content_type = page.response_headers["Content-Type"]
    expect(content_disposition).to match(/^attachment/)
    expect(content_type).to eq("text/csv")
  end

  scenario "download CSV through reporting" do
    visit reports_url(subdomain: subdomain)
    click_link I18n.t("entries.download_csv")

    content_disposition = page.response_headers["Content-Disposition"]
    content_type = page.response_headers["Content-Type"]
    expect(content_disposition).to match(/^attachment/)
    expect(content_type).to eq("text/csv")
  end

  scenario "CSV download respects the active report filters" do
    client = create(:client)
    billable = create(:project, client: client, billable: true)
    internal = create(:project, client: client, billable: false)
    create(:hour, project: billable, description: "billable work")
    create(:hour, project: internal, description: "internal work")

    visit reports_url(subdomain: subdomain)
    select(I18n.t("entry_filters.billable"), from: "entry_filter_billable")
    find(:css, "input[value='#{I18n.t('billables.buttons.filter')}']").click
    click_link I18n.t("entries.download_csv")

    expect(page.response_headers["Content-Type"]).to eq("text/csv")
    expect(page.body).to include("billable work")
    expect(page.body).not_to include("internal work")
  end
end
