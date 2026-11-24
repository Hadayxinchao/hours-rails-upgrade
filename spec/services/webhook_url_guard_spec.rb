describe WebhookUrlGuard do
  def check(url, resolves_to: nil)
    allow(Resolv).to receive(:getaddresses).and_return(Array(resolves_to)) if resolves_to
    described_class.check!(url)
  end

  it "accepts public https URLs and returns the checked address to connect to" do
    uri, ip = check("https://hooks.example.com/hours", resolves_to: "93.184.216.34")
    expect([uri.host, ip]).to eq ["hooks.example.com", "93.184.216.34"]
  end

  {
    "loopback" => ["https://127.0.0.1/x", nil],
    "cloud metadata service" => ["https://169.254.169.254/latest/meta-data/", nil],
    "private network" => ["https://10.0.0.5/", nil],
    "IPv6 loopback" => ["https://[::1]/", nil],
    "IPv4-mapped IPv6" => ["https://[::ffff:127.0.0.1]/", nil],
    "a public-looking name that resolves inside" => ["https://internal.example.com/", "192.168.1.10"],
    "a name with one private answer among public ones" => ["https://mixed.example.com/", ["93.184.216.34", "10.1.2.3"]]
  }.each do |label, (url, resolves_to)|
    it "blocks #{label}" do
      expect { check(url, resolves_to: resolves_to) }.to raise_error(WebhookUrlGuard::Blocked, /private or reserved/)
    end
  end

  it "requires https and no credentials in the URL" do
    expect { check("http://hooks.example.com/") }.to raise_error(WebhookUrlGuard::Blocked, /https/)
    expect { check("https://user:pass@hooks.example.com/") }.to raise_error(WebhookUrlGuard::Blocked, /password/)
    expect { check("ftp://hooks.example.com/") }.to raise_error(WebhookUrlGuard::Blocked)
  end

  it "is enforced when a webhook is saved" do
    endpoint = WebhookEndpoint.new(url: "https://169.254.169.254/", events: ["hour.created"])
    expect(endpoint).not_to be_valid
    expect(endpoint.errors[:url]).to include("points to a private or reserved address")
  end
end
