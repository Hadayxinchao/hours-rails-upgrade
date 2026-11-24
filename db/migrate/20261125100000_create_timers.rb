# A running timer per user (phase 2, step 2). Stopping it logs an hours entry.
class CreateTimers < ActiveRecord::Migration[8.1]
  def change
    create_table :timers do |t|
      t.references :user, null: false, foreign_key: true, type: :integer, index: { unique: true }
      t.references :project, null: false, foreign_key: true, type: :integer
      t.references :category, null: false, foreign_key: true, type: :integer
      t.string :description
      t.datetime :started_at, null: false
      t.timestamps
    end
  end
end
