describe "Slack /hours command", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:secret) { "slack-signing-secret" }
  let(:subdomain) { generate(:subdomain) }
  let(:owner) { build(:user, first_name: "Linh") }

  before do
    stub_const("ENV", ENV.to_h.merge("SLACK_SIGNING_SECRET" => secret))
    create(:account_with_schema, subdomain: subdomain, owner: owner)
    SlackWorkspace.create!(team_id: "T0ACME01", subdomain: subdomain)
    host! "example.com" # Slack calls one URL, without an account subdomain
  end

  def in_account(&block)
    Apartment::Tenant.switch(subdomain, &block)
  end

  def slash(text, user_id: "U0LINH01", team_id: "T0ACME01", timestamp: Time.current.to_i, signature: nil)
    body = URI.encode_www_form(team_id: team_id, user_id: user_id, command: "/hours", text: text)
    signature ||= "v0=#{OpenSSL::HMAC.hexdigest('SHA256', secret, "v0:#{timestamp}:#{body}")}"
    post "/integrations/slack/commands", params: body,
                                         headers: { "Content-Type" => "application/x-www-form-urlencoded",
                                                    "X-Slack-Request-Timestamp" => timestamp.to_s,
                                                    "X-Slack-Signature" => signature }
    response.parsed_body["text"]
  end

  describe "request verification" do
    it "rejects bad signatures and replayed (old) requests" do
      slash("status", signature: "v0=forged")
      expect(response).to have_http_status(:unauthorized)

      slash("status", timestamp: 10.minutes.ago.to_i)
      expect(response).to have_http_status(:unauthorized)
    end

    it "is unavailable until a signing secret is configured" do
      stub_const("ENV", ENV.to_h.except("SLACK_SIGNING_SECRET"))
      slash("status")
      expect(response).to have_http_status(:service_unavailable)
    end
  end

  it "tells unknown workspaces to connect first" do
    expect(slash("status", team_id: "T0OTHER1")).to eq I18n.t("slack.unknown_workspace")
  end

  it "links a Slack user to a Hours user through a signed, account-bound link" do
    text = slash("status")
    url = text[%r{http\S+}]
    expect(url).to start_with("http://#{subdomain}.example.com/integrations/slack/link?code=")

    host! "#{subdomain}.example.com"
    sign_in owner
    get url
    expect(response.body).to include("U0LINH01")
    post "/integrations/slack/link", params: { code: Rack::Utils.parse_query(URI(url).query)["code"] }
    expect(in_account { User.first.slack_user_id }).to eq "U0LINH01"

    other = generate(:subdomain)
    create(:account_with_schema, subdomain: other, owner: build(:user))
    host! "#{other}.example.com"
    sign_in in_account { User.first } # (signed in elsewhere)
    get url.sub("#{subdomain}.", "#{other}.")
    expect(response).to redirect_to("/")
  end

  context "when linked" do
    before do
      in_account do
        User.first.update!(slack_user_id: "U0LINH01")
        create(:project, name: "Booking app")
        create(:project, name: "Order API")
        create(:project, name: "Order intake")
        create(:category, name: "Development")
      end
    end

    it "logs time with flexible durations and fuzzy names" do
      expect(slash("1.5h booking dev Fixed reminders #backend"))
        .to eq "Logged 1.5 h of Development on Booking app."
      expect(slash("50m booking-app development"))
        .to eq "Logged 1 h of Development on Booking app. (rounded up to the next quarter hour)"

      hours = in_account { Hour.order(:id).map { |h| [h.value, h.description, h.tags.map(&:name)] } }
      expect(hours).to eq [[1.5, "Fixed reminders #backend", ["backend"]], [1, nil, []]]
    end

    it "asks when a name is ambiguous or unknown" do
      expect(slash("1h order dev")).to eq '"order" matches several: Order API, Order intake. Type more of the name.'
      expect(slash("1h nope dev")).to eq 'No project matches "nope".'
      expect(slash("sometime booking dev")).to eq I18n.t("slack.help")
    end

    it "starts, reports and stops a timer" do
      expect(slash("start booking dev Reminder emails")).to eq "Timer started on Booking app (Development). `/hours stop` to log it."
      expect(slash("status")).to start_with("Today: 0 h logged. Timer running on Booking app: 0:00")
      expect(slash("stop")).to eq "Logged 0.25 h of Development on Booking app."
      expect(slash("stop")).to eq I18n.t("slack.no_timer")
    end
  end
end
