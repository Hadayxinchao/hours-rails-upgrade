describe PaperclipLogoMigration do
  let(:root) { Pathname(Dir.mktmpdir) }
  let(:tenant) { Apartment::Tenant.current }
  let(:migration) { described_class.new(root: root, logger: Logger.new(nil)) }

  after { FileUtils.rm_rf(root) }

  def legacy_client(name)
    create(:client, name: name).tap do |client|
      client.update_columns(logo_file_name: "logo.png", logo_content_type: "image/png")
    end
  end

  def place_legacy_file(client)
    path = root.join(described_class.legacy_key(tenant, client))
    FileUtils.mkdir_p(path.dirname)
    FileUtils.cp(Rails.root.join("spec/fixtures/logo.png"), path)
  end

  it "builds the Paperclip id-partitioned key" do
    client = build_stubbed(:client, id: 1234, logo_file_name: "acme.png")

    expect(described_class.legacy_key("acme", client))
      .to eq("system/acme/clients/logos/000/001/234/original/acme.png")
  end

  it "attaches the legacy file with its original name and content type" do
    client = legacy_client("Legacy")
    place_legacy_file(client)

    result = migration.migrate_tenant(tenant)

    client.reload
    expect(result.migrated).to eq(1)
    expect(client.logo).to be_attached
    expect(client.logo.filename.to_s).to eq("logo.png")
    expect(client.logo.content_type).to eq("image/png")
    expect(client.logo.download).to eq(File.binread(Rails.root.join("spec/fixtures/logo.png")))
  end

  it "is idempotent" do
    client = legacy_client("Legacy")
    place_legacy_file(client)

    migration.migrate_tenant(tenant)
    second = migration.migrate_tenant(tenant)

    expect(second.migrated).to eq(0)
    expect(second.skipped).to eq(1)
    expect(ActiveStorage::Attachment.where(record: client).count).to eq(1)
  end

  it "reports missing files and keeps going" do
    missing = legacy_client("Missing")
    present = legacy_client("Present")
    place_legacy_file(present)

    result = migration.migrate_tenant(tenant)

    expect(result.missing).to eq(1)
    expect(result.migrated).to eq(1)
    expect(missing.reload.logo).not_to be_attached
  end

  it "ignores clients without a legacy logo" do
    create(:client)

    expect(migration.migrate_tenant(tenant).to_a).to eq([0, 0, 0])
  end
end
