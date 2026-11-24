describe "API v1", type: :request do
  let(:subdomain) { generate(:subdomain) }
  let(:owner) { build(:user) }
  let!(:account) { create(:account_with_schema, subdomain: subdomain, owner: owner) }
  let(:token) { in_account { ApiToken.issue(user: User.first, name: "CLI").tap(&:save!).plaintext } }
  let(:auth) { { "Authorization" => "Bearer #{token}" } }

  before { host! "#{subdomain}.example.com" }

  def json
    response.parsed_body
  end

  def in_account(&block)
    Apartment::Tenant.switch(subdomain, &block)
  end

  def api(verb, path, params: nil, headers: auth)
    send(verb, "/api/v1#{path}", params: params&.to_json,
                                 headers: headers.merge("Content-Type" => "application/json", "Accept" => "application/json"))
  end

  describe "authentication" do
    it "requires a token and says how to send one" do
      api :get, "/me", headers: {}

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to start_with("Bearer")
      expect_schema("Error", json)
    end

    it "rejects revoked tokens" do
      token
      in_account { ApiToken.last.revoke! }
      api :get, "/me"
      expect(response).to have_http_status(:unauthorized)
    end

    it "doesn't accept one account's token on another account's address" do
      other = generate(:subdomain)
      create(:account_with_schema, subdomain: other, owner: build(:user))
      host! "#{other}.example.com"

      api :get, "/me"

      expect(response).to have_http_status(:unauthorized)
    end

    it "404s for addresses without an account" do
      host! "nobody.example.com"
      api :get, "/me"
      expect(json.dig("error", "code")).to eq "unknown_account"
    end

    it "stores only a digest of the token and records its use" do
      api :get, "/me"
      in_account do
        stored = ApiToken.last
        expect(stored.token_digest).not_to include(token)
        expect(stored.token_digest).to eq ApiToken.digest(token)
        expect(stored.last_used_at).to be_present
      end
    end
  end

  it "GET /me" do
    api :get, "/me"
    expect(json["email"]).to eq owner.email
    expect_schema("User", json)
  end

  describe "projects and categories" do
    it "lists projects with budget usage, paginated" do
      in_account do
        client = create(:client, currency: "EUR")
        project = create(:project, name: "Booking app", client: client, budget: 10, hourly_rate: "80", budget_amount: "500")
        create(:hour, project: project, value: 9)
        create_list(:project, 2)
      end

      api :get, "/projects", params: nil
      get "/api/v1/projects?per_page=2", headers: auth

      expect(response.headers["X-Total-Count"]).to eq "3"
      expect(response.headers["Link"]).to include('rel="next"', "page=2")
      booking = json.find { |p| p["name"] == "Booking app" }
      expect(booking["budgets"]).to contain_exactly(
        include("kind" => "hours", "used" => 9, "limit" => 10, "level" => "warning"),
        include("kind" => "amount", "used" => "720.00", "limit" => "500.00", "level" => "over")
      )
      json.each { |project| expect_schema("Project", project) }
    end

    it "lists categories" do
      in_account { create(:category, name: "Design") }
      api :get, "/categories"
      expect(json.map { |c| c["name"] }).to eq ["Design"]
      json.each { |category| expect_schema("Category", category) }
    end
  end

  describe "hours" do
    let!(:ids) do
      in_account do
        { project: create(:project).id, category: create(:category).id, user: User.first.id }
      end
    end

    it "creates an entry as the token's user, with tags from the description" do
      api :post, "/hours", params: { hour: { project_id: ids[:project], category_id: ids[:category], hours: 1.75,
                                             date: "2026-11-20", description: "Pairing #review" } }

      expect(response).to have_http_status(:created)
      expect(response.headers["Location"]).to end_with("/api/v1/hours/#{json['id']}")
      expect(json).to include("hours" => 1.75, "user_id" => ids[:user], "tags" => ["review"], "date" => "2026-11-20")
      expect_schema("Hour", json)
    end

    it "explains validation errors per field" do
      api :post, "/hours", params: { hour: { project_id: ids[:project], category_id: ids[:category], hours: 1.1 } }

      expect(response).to have_http_status(422)
      expect(json.dig("error", "details", "value")).to eq [I18n.t("errors.messages.quarter_hours")]
      expect_schema("Error", json)
    end

    it "filters, and lets you change only your own entries" do
      mine, theirs = in_account do
        [create(:hour, user: User.first, date: "2026-11-10"), create(:hour, date: "2026-10-01")]
      end

      get "/api/v1/hours?user_id=me&from=2026-11-01", headers: auth
      expect(json.map { |h| h["id"] }).to eq [mine.id]

      api :patch, "/hours/#{theirs.id}", params: { hour: { hours: 2 } }
      expect(response).to have_http_status(:not_found)

      api :patch, "/hours/#{mine.id}", params: { hour: { hours: 2.5 } }
      expect(json["hours"]).to eq 2.5
    end

    it "refuses to change or delete an invoiced entry" do
      hour = in_account do
        project = create(:project, client: create(:client), billable: true, hourly_rate: "50")
        create(:hour, user: User.first, project: project).tap do |h|
          InvoiceBuilder.new(project.client, hour_ids: [h.id]).call
        end
      end

      api :delete, "/hours/#{hour.id}"

      expect(response).to have_http_status(422)
      expect(json.dig("error", "message")).to include("#{Date.current.year}-0001")
    end

    it "rejects malformed dates with 400" do
      get "/api/v1/hours?from=yesterday", headers: auth
      expect(response).to have_http_status(:bad_request)
    end
  end

  it "runs the timer: start, conflict, stop" do
    project_id, category_id = in_account { [create(:project).id, create(:category).id] }

    api :post, "/timer", params: { timer: { project_id: project_id, category_id: category_id } }
    expect(response).to have_http_status(:created)
    expect_schema("Timer", json)

    api :post, "/timer", params: { timer: { project_id: project_id, category_id: category_id } }
    expect(response).to have_http_status(:conflict)

    api :post, "/timer/stop"
    expect(response).to have_http_status(:created)
    expect(json["hours"]).to eq 0.25
    expect_schema("Hour", json)

    api :get, "/timer"
    expect(response).to have_http_status(:not_found)
  end

  it "rate-limits to 300 requests a minute per token" do
    Api::V1::RateLimitStore.backend = ActiveSupport::Cache::MemoryStore.new
    300.times { get "/api/v1/me", headers: auth }
    expect(response).to have_http_status(:ok)

    get "/api/v1/me", headers: auth

    expect(response).to have_http_status(:too_many_requests)
    expect(json.dig("error", "code")).to eq "rate_limited"
  ensure
    Api::V1::RateLimitStore.backend = nil
  end

  it "documents every API route in openapi.yaml, and nothing more" do
    routes = Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s.delete_suffix("(.:format)")
      next unless path.start_with?("/api/v1/") && path != "/api/v1/openapi.yaml"

      [route.verb.downcase, path.delete_prefix("/api/v1").gsub(/:(\w+)/, '{\1}')]
    end
    documented = YAML.safe_load_file(Rails.root.join("docs/api/openapi.yaml"))["paths"].flat_map do |path, ops|
      ops.keys.reject { |k| k == "parameters" }.map { |verb| [verb, path] }
    end

    expect(routes.uniq.sort - [["put", "/hours/{id}"]]).to match_array(documented)
  end

  it "serves the OpenAPI document with this account's address" do
    get "/api/v1/openapi.yaml"
    expect(YAML.safe_load(response.body)["servers"]).to eq [{ "url" => "http://#{subdomain}.example.com/api/v1" }]
  end
end
