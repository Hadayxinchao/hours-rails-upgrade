describe AvatarHelper do
  describe "#gravatar_url" do
    it "hashes the trimmed, downcased email (Gravatar spec)" do
      expect(helper.gravatar_url(" User@Example.COM "))
        .to eq("https://secure.gravatar.com/avatar/b58996c504c5638798eb6b511e6f49af?d=blank")
    end

    it "adds a size parameter" do
      expect(helper.gravatar_url("user@example.com", size: 80)).to end_with("?d=blank&s=80")
    end
  end

  describe "#avatar_image_tag" do
    it "renders a decorative img (empty alt)" do
      user = build(:user, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com")
      img = Nokogiri::HTML.fragment(helper.avatar_image_tag(user, class: "image-circle")).at_css("img")

      expect(img["src"]).to eq(helper.gravatar_url("ada@example.com"))
      expect(img["alt"]).to eq("")
      expect(img["class"]).to eq("image-circle")
    end
  end
end
