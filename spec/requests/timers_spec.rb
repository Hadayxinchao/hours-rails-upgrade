describe "Timers with Turbo Streams", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:subdomain) { generate(:subdomain) }
  let(:user) { build(:user) }
  let!(:account) { create(:account_with_schema, subdomain: subdomain, owner: user) }
  let(:turbo) { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }

  before do
    host! "#{subdomain}.example.com"
    sign_in user
  end

  it "replaces the timer panel and the navbar indicator in place" do
    project, category = Apartment::Tenant.switch(subdomain) { [create(:project), create(:category)] }

    post "/timer", params: { timer: { project_id: project.id, category_id: category.id } }, headers: turbo

    expect(response.media_type).to eq "text/vnd.turbo-stream.html"
    expect(response.body).to include('<turbo-stream action="replace" target="timer">')
    expect(response.body).to include('<turbo-stream action="replace" target="timer-indicator">')
    expect(response.body).to include('data-controller="timer"')
  end

  it "does not replace a running timer when started again" do
    project, category = Apartment::Tenant.switch(subdomain) { [create(:project), create(:category)] }
    params = { timer: { project_id: project.id, category_id: category.id } }
    post "/timer", params: params, headers: turbo
    first_start = Apartment::Tenant.switch(subdomain) { Timer.last.started_at }

    post "/timer", params: params, headers: turbo

    expect(response.body).to include(I18n.t("timers.already_running"))
    expect(Apartment::Tenant.switch(subdomain) { Timer.pluck(:started_at) }).to eq [first_start]
  end
end
