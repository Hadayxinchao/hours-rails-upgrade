# Quarter-hour precision (0.25 h) for hours entries, needed by the timer.
# Existing whole-hour values convert exactly; mileage stays whole kilometres.
class ChangeHoursValueToDecimal < ActiveRecord::Migration[8.1]
  def up
    change_column :hours, :value, :decimal, precision: 6, scale: 2, null: false
  end

  def down
    change_column :hours, :value, :integer, null: false, using: "ROUND(value)::integer"
  end
end
