# A personal API token. Only a SHA-256 digest is stored: the token is shown
# once when created and can't be recovered, only revoked. Tokens belong to an
# account schema, so they only work on that account's subdomain.
class ApiToken < ApplicationRecord
  PREFIX = "hrs_".freeze

  belongs_to :user

  validates :name, presence: true, length: { maximum: 60 }

  scope :active, -> { where(revoked_at: nil) }

  attr_reader :plaintext

  def self.issue(user:, name:)
    plaintext = "#{PREFIX}#{SecureRandom.base58(32)}"
    token = new(user: user, name: name, token_digest: digest(plaintext), token_prefix: plaintext.first(8))
    token.instance_variable_set(:@plaintext, plaintext)
    token
  end

  def self.authenticate(plaintext)
    return nil unless plaintext.is_a?(String) && plaintext.start_with?(PREFIX)

    active.includes(:user).find_by(token_digest: digest(plaintext))
  end

  def self.digest(plaintext)
    OpenSSL::Digest::SHA256.hexdigest(plaintext)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  # Throttled so busy API clients don't write on every request.
  def touch_last_used
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < 1.minute.ago
  end
end
