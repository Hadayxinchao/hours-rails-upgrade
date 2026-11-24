feature "User invoices a client" do
  let(:subdomain) { generate(:subdomain) }
  let(:user) { build(:user) }

  before do
    create(:account_with_schema, subdomain: subdomain, owner: user)
    sign_in_user(user, subdomain: subdomain)
    @client = create(:client, name: "Northwind", currency: "EUR")
    @project = create(:project, name: "Webshop", client: @client, billable: true)
    create(:hour, project: @project, value: 3, user: User.first)
    create(:hour, project: @project, value: 2, user: User.first)
  end

  scenario "sets a rate, creates an invoice from billables, sends it, downloads the PDF and gets paid" do
    visit edit_project_url(@project, subdomain: subdomain)
    fill_in "project_hourly_rate", with: "85.50"
    click_button "Update Project"

    visit billables_url(subdomain: subdomain)
    within(".invoice-summary") do
      expect(page).to have_content "Northwind"
      expect(page).to have_content "€427.50"
      click_link I18n.t("invoices.create_for")
    end

    fill_in "tax_rate", with: "21"
    click_button I18n.t("invoices.actions.create")

    expect(page).to have_content I18n.t("invoices.notices.created", number: "#{Date.current.year}-0001")
    expect(page).to have_content "€427.50"
    expect(page).to have_content "€89.78"
    expect(page).to have_content "€517.28"

    click_button I18n.t("invoices.actions.mark_sent")
    expect(page).to have_content I18n.t("invoices.statuses.sent")

    click_link I18n.t("invoices.actions.pdf")
    expect(page.response_headers["Content-Type"]).to eq "application/pdf"
    expect(page.body).to start_with "%PDF"

    visit invoices_url(subdomain: subdomain)
    click_link "#{Date.current.year}-0001"
    click_button I18n.t("invoices.actions.mark_paid")
    expect(page).to have_css(".invoice-status--paid")

    visit billables_url(subdomain: subdomain)
    expect(page).to have_no_css(".invoice-summary")
  end

  scenario "is told to set a rate first" do
    visit new_invoice_url(client_id: @client.id, subdomain: subdomain)
    click_button I18n.t("invoices.actions.create")

    expect(page).to have_content I18n.t("invoices.errors.missing_hourly_rate", project: "Webshop")
    expect(Invoice.count).to eq 0
  end

  scenario "voids a sent invoice and the entries become billable again" do
    @project.update!(hourly_rate: "50")
    visit new_invoice_url(client_id: @client.id, subdomain: subdomain)
    click_button I18n.t("invoices.actions.create")
    click_button I18n.t("invoices.actions.mark_sent")
    click_button I18n.t("invoices.actions.void")

    expect(page).to have_css(".invoice-status--void")
    visit billables_url(subdomain: subdomain)
    expect(page).to have_content "€250.00"
  end
end
