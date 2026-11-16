describe ApplicationHelper do
  include ApplicationHelper

  describe "#client_title" do
    it "returns an image when there's a logo" do
      client = create(:client)
      client.logo.attach(fixture_file_upload("logo.png", "image/png"))

      img = Nokogiri::HTML.fragment(helper.client_title(client)).at_css("img.logo")

      expect(img["src"]).to include("/rails/active_storage/representations/")
      expect(img["alt"]).to eq("Logo")
    end

    it "shows a hashtel circle when there's no logo" do
      client = create(:client)

      expect(helper.client_title(client)).to include('<span class="color"')
    end
  end
end
