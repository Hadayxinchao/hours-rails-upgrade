# Active Record Encryption (used for webhook signing secrets, which must be
# readable to sign requests). Keys come from the environment; without them
# they are derived from SECRET_KEY_BASE, so rotating that key also requires
# setting the old derived keys explicitly (see docs/phase-2/LOG.md).
derived = lambda do |name|
  ENV["ACTIVE_RECORD_ENCRYPTION_#{name.upcase}"].presence ||
    Rails.application.key_generator.generate_key("active_record_encryption/#{name}", 32).unpack1("H*")
end

ActiveRecord::Encryption.configure(
  primary_key: derived.call("primary_key"),
  deterministic_key: derived.call("deterministic_key"),
  key_derivation_salt: derived.call("key_derivation_salt"),
  hash_digest_class: OpenSSL::Digest::SHA256,
  support_sha1_for_non_deterministic_encryption: false
)
