# An invoice to one client, built by InvoiceBuilder from unbilled entries.
#
#   draft ──send──▶ sent ──pay──▶ paid
#     │               │
#   delete          void   (both release the entries for re-invoicing)
class Invoice < ApplicationRecord
  STATUSES = %w[draft sent paid void].freeze

  belongs_to :client
  has_many :lines, -> { order(:position, :id) }, class_name: "InvoiceLine", inverse_of: :invoice,
                                                 dependent: :delete_all
  has_many :hours, dependent: :nullify
  has_many :mileages, dependent: :nullify

  validates :number, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :currency, inclusion: { in: Money.codes }
  validates :issued_on, :due_on, presence: true
  validates :tax_rate, numericality: { greater_than_or_equal_to: 0, less_than: 100 }
  validate :due_after_issue

  scope :recent_first, -> { order(issued_on: :desc, id: :desc) }

  STATUSES.each do |name|
    define_method(:"#{name}?") { status == name }
  end

  def overdue?(today = Date.current)
    sent? && due_on < today
  end

  def display_status(today = Date.current)
    overdue?(today) ? "overdue" : status
  end

  # Allocates the next "YYYY-NNNN" for this account. The advisory lock is held
  # until the surrounding transaction ends, so two concurrent invoices can't
  # read the same maximum; the unique index is the backstop.
  def self.next_number(year)
    connection.execute("SELECT pg_advisory_xact_lock(hashtext(current_schema() || ':invoice_number'))")
    last = where("number LIKE ?", "#{year}-%").maximum(:number)
    format("%<year>d-%<seq>04d", year: year, seq: last.to_s.split("-").last.to_i + 1)
  end

  def recalculate_totals
    self.subtotal_cents = lines.sum(&:amount_cents)
    self.tax_cents = (BigDecimal(subtotal_cents) * tax_rate / 100).round(0, :half_up).to_i
    self.total_cents = subtotal_cents + tax_cents
  end

  def mark_sent!
    transition!(from: "draft", to: "sent", sent_at: Time.current)
  end

  def mark_paid!
    transition!(from: "sent", to: "paid", paid_at: Time.current)
  end

  def void!
    transaction do
      transition!(from: "sent", to: "void", voided_at: Time.current)
      release_entries
    end
  end

  # Only drafts can be deleted; issued invoices are voided so the number stays.
  def destroy_draft!
    raise InvalidTransition, "only a draft can be deleted" unless draft?

    transaction do
      release_entries
      destroy!
    end
  end

  class InvalidTransition < StandardError; end

  private

  def transition!(from:, to:, **timestamps)
    with_lock do
      raise InvalidTransition, "can't go from #{status} to #{to}" unless status == from

      update!(status: to, **timestamps)
    end
  end

  def release_entries
    [Hour, Mileage].each do |model|
      model.where(invoice_id: id).update_all(invoice_id: nil, billed: false, updated_at: Time.current)
    end
  end

  def due_after_issue
    return if issued_on.blank? || due_on.blank? || due_on >= issued_on

    errors.add(:due_on, :before_issue_date)
  end
end
