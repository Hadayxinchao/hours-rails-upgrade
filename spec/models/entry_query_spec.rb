describe EntryQuery do
  let(:client) { create(:client) }
  let(:project) { create(:project, archived: true, client: client) }
  let!(:hour) do
    create(:hour, billed: false, project: project, date: 20.days.ago)
  end
  let!(:mileage) do
    create(:mileage, billed: false, project: project, date: 20.days.ago)
  end
  let!(:mileage2) { create(:mileage, billed: true, date: 10.days.ago) }
  let!(:hour2) { create(:hour, billed: true, date: 10.days.ago) }
  let(:params) { {} }

  describe "#filter" do
    it "filters the entries on project id" do
      expect(hours_filter(project_id: hour.project.id).count).to eq(1)
      expect(mileages_filter(project_id: mileage.project.id).count).to eq(1)
    end

    it "filters the entries on client_id" do
      expect(hours_filter(client_id: hour.client.id).count).to eq(1)
      expect(mileages_filter(client_id: mileage.client.id).count).to eq(1)
    end

    it "filters the entries on from_date" do
      expect(hours_filter(from_date: hour.date + 1.day).count).to eq(1)
      expect(mileages_filter(from_date: mileage.date + 1.day).count).to eq(1)
    end

    it "filters the entries on to date" do
      expect(hours_filter(to_date: hour2.date - 1.day).count).to eq(1)
      expect(mileages_filter(to_date: mileage2.date - 1.day).count).to eq(1)
    end

    it "filters the entries on not billed" do
      expect(hours_filter(billed: hour.billed).count).to eq(1)
      expect(mileages_filter(billed: mileage.billed).count).to eq(1)
    end

    it "filters the entries on archived" do
      expect(hours_filter(archived: true).count).to eq(1)
      expect(mileages_filter(archived: true).count).to eq(1)
    end

    it "ignores keys that are not whitelisted filters" do
      # Before the fix, entry_filter[delete_by]=1=1 in a URL ran
      # Hour.delete_by("1=1") and wiped every entry in the account.
      expect { hours_filter(delete_by: "1=1") }.not_to change(Hour, :count)
      expect { hours_filter(update_all: "value = 0") }
        .not_to(change { Hour.order(:id).pluck(:value) })
      expect(hours_filter(delete_by: "1=1").count).to eq(Hour.count)
    end

    it "does not leak the entry type between queries (thread safety)" do
      hours = EntryQuery.new(Hour.all, { from_date: 30.days.ago.to_date }, "hours")
      EntryQuery.new(Mileage.all, {}, "mileages")

      expect(hours.filter.to_sql).to include('"hours"."date" >=')
    end

    it "filters on all params" do
      expect(hours_filter(
        billed: hour.billed,
        to_date: hour2.date + 1.day,
        from_date: hour.date - 1.day,
        client_id: hour.client.id,
        project_id: hour.project.id
      ).count).to eq(1)

      expect(mileages_filter(
        billed: mileage.billed,
        to_date: mileage2.date + 1.day,
        from_date: mileage.date - 1.day,
        client_id: mileage.client.id,
        project_id: mileage.project.id
      ).count).to eq(1)
    end

    def mileages_filter(params)
      EntryQuery.new(Mileage.all, params, "mileages").filter
    end

    def hours_filter(params)
      EntryQuery.new(Hour.all, params, "hours").filter
    end
  end
end
