# Hours are stored as decimal(6,2) in quarter-hour steps. In Ruby they are
# shown as an Integer when whole (3, not "3.0") and a Float otherwise (1.5),
# so views, CSV exports and chart JSON keep their existing format.
module HoursValue
  STEP = BigDecimal("0.25")

  module_function

  def normalize(value)
    return value if value.nil?

    decimal = BigDecimal(value.to_s)
    decimal.frac.zero? ? decimal.to_i : decimal.round(2).to_f
  end

  def normalize_hash(hash)
    hash.transform_values { |value| normalize(value) }
  end

  # 47 minutes -> 1.0, 5 minutes -> 0.25: round up to the next quarter, at least one.
  def from_seconds(seconds)
    quarters = [(seconds / 900.0).ceil, 1].max
    normalize(STEP * quarters)
  end
end
