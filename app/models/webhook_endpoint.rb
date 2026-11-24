# A URL that receives signed JSON events. The secret is encrypted at rest
# (Active Record Encryption): unlike API tokens it must be readable, to sign.
class WebhookEndpoint < ApplicationRecord
  EVENTS = %w[hour.created hour.updated hour.deleted invoice.sent invoice.paid].freeze
  DISABLE_AFTER_FAILURES = 15

  encrypts :secret

  validates :url, presence: true, length: { maximum: 500 }
  validate :url_is_public_http
  validate :events_are_known

  before_validation { self.secret ||= "whsec_#{SecureRandom.base58(32)}" }
  before_validation { self.events = Array(events).compact_blank.uniq }

  scope :active, -> { where(active: true) }
  scope :for_event, ->(event) { active.where("? = ANY (events)", event) }

  def record_delivery(status: nil, error: nil)
    if error.nil? && status.to_i.between?(200, 299)
      update_columns(last_delivered_at: Time.current, last_status: status, last_error: nil, consecutive_failures: 0)
    else
      failures = consecutive_failures + 1
      update_columns(last_status: status, last_error: error.to_s.truncate(250), consecutive_failures: failures,
                     active: failures < DISABLE_AFTER_FAILURES)
    end
  end

  private

  # Checked again at delivery time (DNS can change); this gives early feedback.
  def url_is_public_http
    WebhookUrlGuard.check!(url, resolve: false)
  rescue WebhookUrlGuard::Blocked => error
    errors.add(:url, error.message)
  end

  def events_are_known
    errors.add(:events, :blank) if events.empty?
    errors.add(:events, :inclusion) if (events - EVENTS).any?
  end
end
