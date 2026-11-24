describe ApplicationCable::Connection, type: :channel do
  let(:user) { build(:user) }

  # spec_helper includes ActionDispatch::TestProcess everywhere; its #cookies
  # shadows the one Action Cable's connection test helpers rely on.
  def cookies
    ActionCable::Connection::TestCase::Behavior.instance_method(:cookies).bind_call(self)
  end

  before { create(:account_with_schema, subdomain: "acme", owner: user) }

  it "identifies the signed-in user inside the account's schema" do
    warden = double(user: nil)
    allow(warden).to receive(:user) { User.find_by(email: user.email) }

    connect "/cable", headers: { "HOST" => "acme.example.com" }, env: { "warden" => warden }

    expect(connection.tenant).to eq "acme"
    expect(connection.current_user.email).to eq user.email
  end

  it "rejects unknown subdomains and anonymous visitors" do
    expect { connect "/cable", headers: { "HOST" => "nope.example.com" }, env: { "warden" => double(user: nil) } }
      .to have_rejected_connection
    expect { connect "/cable", headers: { "HOST" => "acme.example.com" }, env: { "warden" => double(user: nil) } }
      .to have_rejected_connection
  end
end
