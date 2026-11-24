describe DemoAccount do
  def in_demo(&block)
    Apartment::Tenant.switch(DemoAccount::SUBDOMAIN, &block)
  end

  it "builds the demo account with a working login and current data" do
    DemoAccount.reset!

    account = Account.find_by!(subdomain: DemoAccount::SUBDOMAIN)
    in_demo do
      owner = User.find_by!(email: DemoAccount::EMAIL)
      expect(account.owner_id).to eq owner.id
      expect(owner).to be_confirmed
      expect(owner.valid_password?(DemoAccount::PASSWORD)).to be true
      expect(User.count).to eq 6
      expect(Project.count).to eq 7
      expect(Hour.maximum(:date)).to be >= Date.current - 3
      expect(Hour.where(billed: false)).to exist
      expect(Mileage.count).to be > 0
      tagged = Tagging.includes(:hour, :tag).first
      expect(tagged.hour.description).to include("##{tagged.tag.name}")
    end
  end

  it "rebuilds from scratch on reset, dropping visitors' changes" do
    DemoAccount.reset!
    counts = in_demo { [Hour.count, Client.count] }
    in_demo { Client.create!(name: "Added by a visitor") }

    DemoAccount.reset!

    expect(Account.where(subdomain: DemoAccount::SUBDOMAIN).count).to eq 1
    expect(in_demo { [Hour.count, Client.count] }).to eq counts
    expect(in_demo { Client.exists?(name: "Added by a visitor") }).to be false
  end

  it "seeds only when the account is missing" do
    expect(DemoAccount.seed_if_missing).to be true
    expect(DemoAccount.seed_if_missing).to be false
  end
end
