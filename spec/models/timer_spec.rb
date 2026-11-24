describe Timer do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:category) { create(:category) }
  let(:started_at) { Time.zone.local(2026, 11, 24, 23, 30) }
  let(:timer) do
    Timer.create!(user: user, project: project, category: category,
                  description: "Fix reminders #backend", started_at: started_at)
  end

  it "logs the time rounded up to the next quarter hour, dated on the start day" do
    hour = timer.stop!(started_at + 47.minutes)

    expect(hour).to be_persisted
    expect(hour).to have_attributes(value: 1, date: Date.new(2026, 11, 24), project: project,
                                    category: category, user: user)
    expect(hour.tags.map(&:name)).to eq ["backend"]
    expect(Timer.exists?(timer.id)).to be false
  end

  it "keeps the timer and explains when it ran for more than 24 hours" do
    hour = timer.stop!(started_at + 25.hours)

    expect(hour).not_to be_persisted
    expect(hour.errors[:base]).to include(I18n.t("errors.messages.timer_too_long"))
    expect(Timer.exists?(timer.id)).to be true
  end

  it "allows one running timer per user" do
    timer
    expect(Timer.new(user: user, project: project, category: category, started_at: Time.current))
      .not_to be_valid
  end
end
