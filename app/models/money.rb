# Integer minor units + ISO currency code; no floats anywhere.
module Money
  # code => [symbol, decimals]
  CURRENCIES = {
    "USD" => ["$", 2], "EUR" => ["€", 2], "GBP" => ["£", 2], "AUD" => ["A$", 2],
    "CAD" => ["C$", 2], "SGD" => ["S$", 2], "JPY" => ["¥", 0], "VND" => ["₫", 0]
  }.freeze

  module_function

  def codes
    CURRENCIES.keys
  end

  def decimals(currency)
    CURRENCIES.fetch(currency).last
  end

  # "85.5" -> 8550 (USD), "250000" -> 250000 (VND). Rounds half-up.
  def to_minor(value, currency)
    (BigDecimal(value.to_s.delete(",").strip) * 10**decimals(currency)).round(0, :half_up).to_i
  end

  def to_decimal(cents, currency)
    BigDecimal(cents) / 10**decimals(currency)
  end

  # For form fields: 8550, "USD" -> "85.50"; nil stays nil.
  def to_input(cents, currency)
    cents && Kernel.format("%.#{decimals(currency)}f", to_decimal(cents, currency))
  end

  # 123456, "USD" -> "$1,234.56"; negative amounts keep the sign in front.
  def format(cents, currency)
    symbol, places = CURRENCIES.fetch(currency)
    amount = ActiveSupport::NumberHelper.number_to_delimited(
      Kernel.format("%.#{places}f", to_decimal(cents.abs, currency))
    )
    "#{'-' if cents.negative?}#{symbol}#{amount}"
  end
end
