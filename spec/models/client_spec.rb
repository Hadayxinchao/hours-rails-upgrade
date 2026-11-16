# == Schema Information
#
# Table name: clients
#
#  id                :integer          not null, primary key
#  name              :string           default(""), not null
#  description       :string           default("")
#  logo_file_name    :string
#  logo_content_type :string
#  logo_file_size    :integer
#  logo_updated_at   :datetime
#  created_at        :datetime
#  updated_at        :datetime
#

describe Client do
  let(:client) { create(:client) }

  describe "validations" do
    it { should validate_presence_of :name }
    it { should validate_uniqueness_of(:name).case_insensitive }
  end

  describe "associations" do
    it { should have_many :projects }
  end

  describe "#by_name" do
    it "orders by name case insensitive" do
      create(:client, name: "B")
      a = create(:client, name: "a")
      expect(Client.by_name.first).to eq(a)
    end
  end

  describe "logo" do
    it "accepts an image" do
      client = build(:client)
      client.logo.attach(fixture_file_upload("logo.png", "image/png"))

      expect(client).to be_valid
    end

    it "rejects a file that is not an image" do
      client = build(:client)
      client.logo.attach(io: StringIO.new("not an image"), filename: "logo.txt",
                         content_type: "text/plain")

      expect(client).not_to be_valid
      expect(client.errors[:logo]).to be_present
    end

    it "has a 100x100 thumbnail variant" do
      client = create(:client)
      client.logo.attach(fixture_file_upload("logo.png", "image/png"))

      expect(client.logo_thumbnail.variation.transformations)
        .to eq(resize_to_fill: [100, 100])
    end
  end
end
