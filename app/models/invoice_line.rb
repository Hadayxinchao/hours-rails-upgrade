# One line of an invoice. Prices are copied from the project when the invoice
# is built, so later rate changes never alter an issued invoice.
class InvoiceLine < ApplicationRecord
  KINDS = %w[hours mileage].freeze

  belongs_to :invoice, inverse_of: :lines
  belongs_to :project

  validates :kind, inclusion: { in: KINDS }
  validates :description, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price_cents, :amount_cents, numericality: { greater_than_or_equal_to: 0 }
end
