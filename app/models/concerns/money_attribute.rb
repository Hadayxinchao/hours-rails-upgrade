# Exposes an integer minor-units column (e.g. hourly_rate_cents) as a decimal
# attribute for forms (hourly_rate = "85.50"), using the record's currency.
module MoneyAttribute
  extend ActiveSupport::Concern

  class_methods do
    def money_attribute(name)
      column = :"#{name}_cents"

      define_method(name) do
        cents = public_send(column)
        cents && Money.to_decimal(cents, money_currency)
      end

      define_method(:"#{name}=") do |value|
        public_send(:"#{column}=", value.blank? ? nil : Money.to_minor(value, money_currency))
      end

      validates column, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
    end
  end
end
