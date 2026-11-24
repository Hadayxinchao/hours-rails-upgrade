describe "Inline editing of hours on My Entries", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:subdomain) { generate(:subdomain) }
  let(:user) { build(:user) }
  let!(:account) { create(:account_with_schema, subdomain: subdomain, owner: user) }
  let(:turbo) { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }
  let(:hour) { Apartment::Tenant.switch(subdomain) { create(:hour, user: User.first, value: 2) } }
  let(:row) { "hour_#{hour.id}" }

  before do
    host! "#{subdomain}.example.com"
    sign_in user
  end

  def patch_hour(attrs)
    patch "/hours/#{hour.id}",
          params: { hour: { project_id: hour.project_id, category_id: hour.category_id,
                            description: "", date: "2026-11-20" }.merge(attrs) },
          headers: turbo
  end

  it "swaps the row for a form, and back on cancel" do
    get "/hours/#{hour.id}/edit", headers: turbo
    expect(response.body).to include(%(<turbo-stream action="replace" target="#{row}">))
    expect(response.body).to include("inline-entry-form")

    get "/hours/#{hour.id}/edit", params: { cancel: 1 }, headers: turbo
    expect(response.body).not_to include("inline-entry-form")
  end

  it "saves and returns the updated row" do
    patch_hour(value: "1.75", description: "Pairing #review")

    expect(response.body).to include(%(target="#{row}")).and include("1.75")
    expect(response.body).not_to include("inline-entry-form")
    Apartment::Tenant.switch(subdomain) do
      expect(hour.reload).to have_attributes(value: 1.75, date: Date.new(2026, 11, 20))
    end
  end

  it "keeps the form open with the reason when the entry can't be saved" do
    patch_hour(value: "1.1")

    expect(response.body).to include("inline-entry-form")
    expect(response.body).to include(CGI.escapeHTML(I18n.t("errors.messages.quarter_hours")))
  end
end
