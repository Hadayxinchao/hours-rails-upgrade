# One-off data migration: copies client logos stored by Paperclip into
# Active Storage, tenant by tenant. Safe to re-run: clients that already
# have an attached logo are skipped, and the legacy files/columns are left
# untouched so the old version can still be rolled back to.
#
#   bin/rails paperclip:migrate_logos                       # files under public/system
#   LEGACY_STORAGE=s3 LEGACY_S3_PREFIX=app/public/ \
#     bin/rails paperclip:migrate_logos                     # files on S3 (S3_BUCKET_NAME)
#
# Legacy layout (config/initializers/paperclip.rb before the upgrade):
#   system/:tenant/clients/logos/:id_partition/original/:filename
class PaperclipLogoMigration
  Result = Struct.new(:migrated, :skipped, :missing)

  def initialize(source: ENV.fetch("LEGACY_STORAGE", "local"),
                 root: Rails.root.join("public"),
                 s3_prefix: ENV.fetch("LEGACY_S3_PREFIX", ""),
                 logger: Logger.new($stdout))
    @source = source
    @root = Pathname(root)
    @s3_prefix = s3_prefix
    @logger = logger
  end

  def run
    Account.pluck(:subdomain).each_with_object({}) do |tenant, results|
      results[tenant] = Apartment::Tenant.switch(tenant) { migrate_tenant(tenant) }
    end
  end

  def migrate_tenant(tenant)
    result = Result.new(0, 0, 0)

    Client.where.not(logo_file_name: [nil, ""]).find_each do |client|
      if client.logo.attached?
        result.skipped += 1
        next
      end

      key = self.class.legacy_key(tenant, client)
      io = open_legacy(key)
      unless io
        @logger.warn("[#{tenant}] client #{client.id}: missing #{key}")
        result.missing += 1
        next
      end

      client.logo.attach(io: io, filename: client.logo_file_name,
                         content_type: client.logo_content_type)
      result.migrated += 1
    end

    @logger.info("[#{tenant}] migrated=#{result.migrated} skipped=#{result.skipped} missing=#{result.missing}")
    result
  end

  def self.legacy_key(tenant, client)
    partition = format("%09d", client.id).scan(/\d{3}/).join("/")
    "system/#{tenant}/clients/logos/#{partition}/original/#{client.logo_file_name}"
  end

  private

  def open_legacy(key)
    case @source
    when "local"
      path = @root.join(key)
      File.open(path, "rb") if path.file?
    when "s3"
      open_s3("#{@s3_prefix}#{key}")
    else
      raise ArgumentError, "LEGACY_STORAGE must be local or s3, got #{@source.inspect}"
    end
  end

  def open_s3(key)
    require "aws-sdk-s3"
    @s3 ||= Aws::S3::Client.new(region: ENV.fetch("AWS_REGION", "eu-west-1"))
    @s3.get_object(bucket: ENV.fetch("S3_BUCKET_NAME"), key: key).body
  rescue Aws::S3::Errors::NoSuchKey
    nil
  end
end
