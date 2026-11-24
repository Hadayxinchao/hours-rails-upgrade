describe BudgetUsage do
  let(:client) { create(:client, currency: "EUR") }
  let(:project) do
    create(:project, client: client, budget: 10, budget_amount: "1000", hourly_rate: "100", mileage_rate: "0.5")
  end

  it "measures hours and amount budgets, with levels from 80% and 100%" do
    create(:hour, project: project, value: "8.5")
    create(:mileage, project: project, value: 20) # €10

    hours, amount = BudgetUsage.for(project.reload)

    expect([hours.kind, hours.used, hours.limit, hours.percentage, hours.level]).to eq ["hours", 8.5, 10, 85.0, "warning"]
    expect([amount.kind, amount.used, amount.limit, amount.percentage, amount.level])
      .to eq ["amount", 86_000, 100_000, 86.0, "warning"]
    expect(hours.reached_thresholds).to eq [80]
  end

  it "skips the amount budget while work is logged without a rate" do
    project.update!(hourly_rate: nil)
    create(:hour, project: project, value: 1)

    expect(BudgetUsage.for(project.reload).map(&:kind)).to eq ["hours"]
  end

  it "is 'over' from 100%" do
    create(:hour, project: project, value: 10)
    expect(BudgetUsage.for(project.reload).first.level).to eq "over"
  end
end
