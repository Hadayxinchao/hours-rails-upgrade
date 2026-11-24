describe "Budget checks are triggered" do
  include ActiveJob::TestHelper

  let(:project) { create(:project, budget: 10) }

  it "when hours are logged, changed or deleted" do
    expect { @hour = create(:hour, project: project) }.to have_enqueued_job(BudgetCheckJob).with(project)
    expect { @hour.update!(value: 2) }.to have_enqueued_job(BudgetCheckJob)
    expect { @hour.destroy }.to have_enqueued_job(BudgetCheckJob)
  end

  it "for both projects when an entry moves to another project" do
    hour = create(:hour, project: project)
    other = create(:project)

    expect { hour.update!(project: other) }
      .to have_enqueued_job(BudgetCheckJob).with(project).and have_enqueued_job(BudgetCheckJob).with(other)
  end

  it "when a budget or rate changes, but not when the project is just touched" do
    project
    expect { project.update!(budget: 20) }.to have_enqueued_job(BudgetCheckJob).with(project)
    expect { project.touch }.not_to have_enqueued_job(BudgetCheckJob)
    expect { project.update!(description: "new") }.not_to have_enqueued_job(BudgetCheckJob)
  end
end
