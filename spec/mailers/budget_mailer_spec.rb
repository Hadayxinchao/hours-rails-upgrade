describe BudgetMailer do
  let(:subdomain) { generate(:subdomain) }
  let(:owner) { build(:user) }

  before do
    create(:account_with_schema, subdomain: subdomain, owner: owner)
    Apartment::Tenant.switch!(subdomain)
  end

  after { Apartment::Tenant.reset }

  it "reports an amount budget in the client's currency with a link into the account" do
    client = create(:client, name: "Northwind", currency: "EUR")
    project = create(:project, name: "Webshop", client: client, budget_amount: "1000", hourly_rate: "105")
    create(:hour, project: project, value: 10)

    mail = BudgetMailer.threshold_reached(project, "amount", 100)

    expect(mail.to).to eq [owner.email]
    expect(mail.subject).to eq "Webshop is over its budget (105%)"
    expect(mail.text_part.body.to_s).to include("€1,050.00 (105.0%)", "€1,000.00", "-€50.00", "Northwind",
                                                "http://#{subdomain}.example.com/projects/webshop")
    expect(mail.html_part.body.to_s).to include("€1,050.00")
  end

  it "sends nothing when the budget was removed before the email ran" do
    project = create(:project, budget: nil)
    expect(BudgetMailer.threshold_reached(project, "hours", 80).message).to be_a(ActionMailer::Base::NullMail)
  end
end
