# Phase 2, step 3: budgets in money as well as hours, and a record of which
# alert thresholds have been sent so each one goes out once.
class AddMoneyBudgetsAndBudgetAlerts < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :budget_amount_cents, :bigint

    create_table :budget_alerts do |t|
      t.references :project, null: false, foreign_key: { on_delete: :cascade }, type: :integer
      t.string :kind, null: false # "hours" or "amount"
      t.integer :threshold, null: false # percent: 80 or 100
      t.timestamps
    end
    add_index :budget_alerts, %i[project_id kind threshold], unique: true
  end
end
