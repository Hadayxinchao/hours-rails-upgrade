# Without JavaScript (rack_test) the timer works through plain form posts and
# redirects; with Turbo the same actions answer with Turbo Streams.
feature "User uses the timer" do
  let(:subdomain) { generate(:subdomain) }
  let(:user) { build(:user) }

  before do
    create(:account_with_schema, subdomain: subdomain, owner: user)
    sign_in_user(user, subdomain: subdomain)
    create(:project, name: "Booking app")
    create(:category, name: "Development")
    visit root_url(subdomain: subdomain)
  end

  scenario "starts a timer, sees it running everywhere, and stops it to log the time" do
    within(".timer-form") do
      select "Booking app", from: "timer_project_id"
      select "Development", from: "timer_category_id"
      fill_in "timer_description", with: "Reminder emails #backend"
      click_button I18n.t("timers.start")
    end

    expect(page).to have_css(".timer-running", text: "Booking app")
    visit user_entries_url(User.first, subdomain: subdomain)
    expect(page).to have_css("#timer-indicator .timer-indicator")

    Timer.last.update!(started_at: 50.minutes.ago)
    visit root_url(subdomain: subdomain)
    click_button I18n.t("timers.stop")

    expect(page).to have_content I18n.t("timers.logged", hours: 1, project: "Booking app")
    expect(page).to have_css(".timer-form")
    expect(Hour.last).to have_attributes(value: 1, description: "Reminder emails #backend")
  end

  scenario "is told what is missing" do
    select "Booking app", from: "timer_project_id"
    click_button I18n.t("timers.start")

    expect(page).to have_content "Category can't be blank"
    expect(Timer.count).to eq 0
  end

  scenario "discards a timer without logging anything" do
    select "Booking app", from: "timer_project_id"
    select "Development", from: "timer_category_id"
    click_button I18n.t("timers.start")
    click_button I18n.t("timers.discard")

    expect(page).to have_content I18n.t("timers.discarded")
    expect(Hour.count).to eq 0
  end
end
