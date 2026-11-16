describe ApplicationHelper do
  include ApplicationHelper

  describe "#client_title" do
    it "returns an image when there's a logo" do
      client = build(:client, logo: fixture_file_upload("logo.png"))

      img = Nokogiri::HTML.fragment(client_title(client)).at_css("img.logo")

      expect(img["src"]).to eq(client.logo_url)
      expect(img["alt"]).to eq("Logo")
    end

    it "shows a hashtel circle when there's no logo" do
      client = create(:client)

      expect(client_title(client)).to include('<span class="color"')
    end
  end
end
