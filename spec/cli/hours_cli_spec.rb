require Rails.root.join("cli/lib/hours_cli")

# End to end: the CLI's HTTP requests are routed by WebMock into this Rails
# app in-process (to_rack), so they go through the real API, tokens, tenant
# selection and database.
describe "hours CLI" do
  let(:subdomain) { generate(:subdomain) }
  let(:owner) { build(:user, first_name: "Linh", last_name: "Tran") }
  let(:url) { "http://#{subdomain}.example.com" }
  let(:config_dir) { Dir.mktmpdir }
  let(:token) { in_account { ApiToken.issue(user: User.first, name: "CLI").tap(&:save!).plaintext } }

  before do
    create(:account_with_schema, subdomain: subdomain, owner: owner)
    # WebMock's to_rack shares one session hash across all requests of a
    # stub; drop it, like a real CLI request (no cookies) would arrive.
    app = ->(env) { Rails.application.call(env.except("rack.session", "rack.session.options")) }
    stub_request(:any, /example\.com/).to_rack(app)
    in_account do
      create(:project, name: "Booking app")
      create(:project, name: "Order API")
      create(:project, name: "Order intake")
      create(:category, name: "Development")
      create(:category, name: "Design")
    end
  end

  after { FileUtils.remove_entry(config_dir) }

  def in_account(&block)
    Apartment::Tenant.switch(subdomain, &block)
  end

  # → [exit code, stdout, stderr]
  def hours(*argv, env: {})
    out = StringIO.new
    err = StringIO.new
    env = { "HOURS_CONFIG" => File.join(config_dir, "config.json"), "HOURS_URL" => url, "HOURS_TOKEN" => token }.merge(env)
    code = HoursCLI::CLI.start(argv, out: out, err: err, env: env)
    [code, out.string, err.string]
  end

  describe "login" do
    it "checks the token, saves it readable by the owner only, then works without env vars" do
      code, out, = hours("login", "--url", url, "--token", token, env: { "HOURS_URL" => nil, "HOURS_TOKEN" => nil })

      expect(code).to eq 0
      expect(out).to include("as Linh Tran")
      path = File.join(config_dir, "config.json")
      expect(File.stat(path).mode & 0o777).to eq 0o600
      expect(hours("whoami", env: { "HOURS_URL" => nil, "HOURS_TOKEN" => nil })[1]).to include("Linh Tran <#{owner.email}>")
    end

    it "refuses a bad token with the auth exit code" do
      code, _, err = hours("login", "--url", url, "--token", "hrs_nope")
      expect([code, err]).to eq [2, "hours: Missing, invalid or revoked API token\n"]
      expect(File).not_to exist(File.join(config_dir, "config.json"))
    end

    it "explains how to log in when nothing is configured" do
      code, _, err = hours("whoami", env: { "HOURS_URL" => nil, "HOURS_TOKEN" => nil })
      expect(code).to eq 2
      expect(err).to include("hours login --url")
    end
  end

  it "logs time with fuzzy names, relative dates and rounding, and options anywhere" do
    code, out, = hours("log", "50m", "book", "dev", "Fixed", "reminders", "#backend", "--date", "yesterday")

    expect(code).to eq 0
    expect(out).to match(/Logged 1 h of Development on Booking app \(#{Date.yesterday}, #\d+\) - rounded up/)
    entry = in_account { Hour.last }
    expect([entry.value, entry.date, entry.description, entry.tags.map(&:name)])
      .to eq [1, Date.yesterday, "Fixed reminders #backend", ["backend"]]

    code, out, = hours("--json", "log", "1.5h", "order-api", "design")
    expect(code).to eq 0
    expect(JSON.parse(out)).to include("hours" => 1.5, "project_id" => in_account { Project.find_by!(name: "Order API").id })
  end

  it "explains ambiguous names and bad input without calling it a crash" do
    expect(hours("log", "1h", "order", "dev")[0..2])
      .to eq [1, "", "hours: \"order\" matches several projects: Order API, Order intake\n"]
    expect(hours("log", "soon", "book", "dev")[2]).to include("Not a duration")
    expect(hours("frobnicate")[2]).to include("Unknown command")
  end

  it "lists, edits and deletes entries" do
    hours("log", "2h", "book", "dev", "First")
    id = in_account { Hour.last.id }

    out = hours("list", "--me")[1]
    expect(out.lines.first.split).to eq %w[ID DATE HOURS PROJECT CATEGORY DESCRIPTION]
    expect(out).to include("Booking app", "Development", "First")

    expect(hours("edit", id.to_s, "--hours", "45m", "--description", "Renamed")[1]).to include("Updated ##{id}: 0.75 h")
    expect(in_account { Hour.find(id).description }).to eq "Renamed"

    expect(hours("delete", "##{id}")[1]).to eq "Deleted ##{id}\n"
    expect(in_account { Hour.exists?(id) }).to be false
  end

  it "shows the server's reason, field by field, when a change is refused" do
    hour = in_account do
      project = create(:project, name: "Billable", client: create(:client), billable: true, hourly_rate: "50")
      create(:hour, user: User.first, project: project).tap { |h| InvoiceBuilder.new(project.client, hour_ids: [h.id]).call }
    end

    code, _, err = hours("delete", hour.id.to_s)

    expect(code).to eq 4
    expect(err).to eq "hours: This entry is on invoice #{Date.current.year}-0001; void the invoice before changing it\n"
  end

  it "lists field errors under the message" do
    in_account { Timer.create!(user: User.first, project: Project.first, category: Category.first, started_at: 25.hours.ago) }
    code, _, err = hours("stop")
    expect(code).to eq 4
    expect(err).to start_with("hours: #{I18n.t('errors.messages.timer_too_long')}")
  end

    it "runs a timer" do
    expect(hours("start", "book", "dev", "Reminder", "emails")[1]).to include("Timer started on Booking app (Development)")
    expect(hours("start", "book", "dev")[0..2]).to eq [4, "", "hours: #{I18n.t('timers.already_running')}\n"]
    expect(hours("status")[1]).to include("Today: 0 h logged.", "Timer running on Booking app: 0:00 - Reminder emails")
    expect(hours("stop")[1]).to include("Logged 0.25 h")
    expect(hours("status")[1]).to eq "Today: 0.25 h logged.\n"
  end

  it "reports per project and category across all pages" do
    in_account do
      user = User.first
      booking = Project.find_by!(name: "Booking app")
      dev = Category.find_by!(name: "Development")
      design = Category.find_by!(name: "Design")
      create_list(:hour, 102, user: user, project: booking, category: dev, value: 1, date: Date.current)
      create(:hour, user: user, project: booking, category: design, value: 2.5, date: Date.current)
      create(:hour, user: user, project: booking, category: design, value: 3, date: Date.current - 40)
    end

    out = hours("report", "--week")[1]
    expect(out.lines.map(&:split)).to eq [%w[PROJECT CATEGORY HOURS], %w[Booking app Development 102],
                                          %w[Booking app Design 2.5], ["Total", "#{Date.current - (Date.current.cwday - 1)}..#{Date.current}:", "104.5", "h"]]
    expect(JSON.parse(hours("--json", "report", "--month")[1])["total_hours"]).to eq 104.5
  end

  it "reports network trouble with its own exit code" do
    stub_request(:any, /example\.com/).to_timeout
    code, _, err = hours("whoami")
    expect(code).to eq 5
    expect(err).to include("Can't reach #{subdomain}.example.com")
  end
end
