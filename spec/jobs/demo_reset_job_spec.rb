describe DemoResetJob do
  it "resets the demo account in demo mode" do
    allow(Hours).to receive(:demo_mode?).and_return(true)
    expect(DemoAccount).to receive(:reset!)
    described_class.perform_now
  end

  it "does nothing outside demo mode" do
    expect(DemoAccount).not_to receive(:reset!)
    described_class.perform_now
  end

  it "is scheduled nightly only when DEMO_MODE is set" do
    config = lambda do |demo|
      erb = ERB.new(Rails.root.join("config/recurring.yml").read)
      ENV["DEMO_MODE"] = demo
      YAML.safe_load(erb.result).fetch("production")
    ensure
      ENV.delete("DEMO_MODE")
    end

    expect(config.call("true")).to include("reset_demo_account" => include("class" => "DemoResetJob"))
    expect(config.call(nil)).not_to have_key("reset_demo_account")
  end
end
