describe BudgetMonitor do
  include ActiveJob::TestHelper

  let(:subdomain) { generate(:subdomain) }
  let(:owner) { build(:user) }
  let(:project) { create(:project, name: "Booking app", budget: 10) }

  before do
    create(:account_with_schema, subdomain: subdomain, owner: owner)
    Apartment::Tenant.switch!(subdomain)
  end

  after { Apartment::Tenant.reset }

  def log(hours)
    create(:hour, project: project, value: hours)
  end

  def check
    perform_enqueued_jobs { BudgetMonitor.new(project.reload).call }
  end

  def sent
    ActionMailer::Base.deliveries.map(&:subject)
  end

  before { ActionMailer::Base.deliveries.clear }

  it "emails the owner once when 80% is reached, and again at 100%" do
    log(7)
    check
    expect(sent).to be_empty

    log(1)
    check
    check
    expect(sent).to eq ["Booking app has used 80% of its hours budget"]
    expect(ActionMailer::Base.deliveries.last.to).to eq [owner.email]

    log(3)
    check
    expect(sent.last).to eq "Booking app is over its hours budget (110%)"
    expect(sent.size).to eq 2
  end

  it "sends one email for the highest threshold when several are passed at once" do
    log(12)
    check

    expect(sent).to eq ["Booking app is over its hours budget (120%)"]
    expect(project.budget_alerts.pluck(:threshold)).to contain_exactly(80, 100)
  end

  it "re-arms an alert when usage drops back below it" do
    log(9)
    check
    project.update!(budget: 20)
    check
    expect(project.budget_alerts).to be_empty

    log(8)
    check
    expect(sent.size).to eq 2
  end

  it "records without emailing when asked (demo data)" do
    log(12)
    perform_enqueued_jobs { BudgetMonitor.new(project).call(notify: false) }

    expect(sent).to be_empty
    expect(project.budget_alerts.count).to eq 2
  end

  it "only the check that inserts the alert sends it, so racing checks don't double-send" do
    log(9)
    BudgetAlert.create!(project: project, kind: "hours", threshold: 80) # the other check won

    check

    expect(sent).to be_empty
  end
end
