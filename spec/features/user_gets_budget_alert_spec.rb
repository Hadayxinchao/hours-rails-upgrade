feature "Budget alerts" do
  let(:subdomain) { generate(:subdomain) }
  let(:user) { build(:user) }

  before do
    create(:account_with_schema, subdomain: subdomain, owner: user)
    sign_in_user(user, subdomain: subdomain)
    ActionMailer::Base.deliveries.clear
  end

  scenario "owner sets a budget, logs time past 80%, sees the warning and gets an email" do
    project = create(:project, name: "Booking app")
    create(:category, name: "Development")
    visit edit_project_url(project, subdomain: subdomain)
    fill_in "project_budget", with: "10"
    click_button "Update Project"

    create(:hour, project: project, value: 6)
    visit root_url(subdomain: subdomain)
    within(".tab-header-and-content-left") do
      select "Booking app", from: "hour_project_id"
      select "Development", from: "hour_category_id"
      fill_in "hour_value", with: "2.5"
      fill_in "hour_date", with: Date.current.strftime("%d/%m/%Y")
      click_button I18n.t("helpers.submit.create")
    end

    visit project_url(project, subdomain: subdomain)
    expect(page).to have_css(".budget-line--warning", text: "8.5 of 10 h")
    expect(ActionMailer::Base.deliveries.map(&:subject)).to eq ["Booking app has used 85% of its hours budget"]
  end
end
