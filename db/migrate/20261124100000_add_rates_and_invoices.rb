# Phase 2, step 1: rates and invoices. Runs in every tenant schema.
class AddRatesAndInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :currency, :string, limit: 3, null: false, default: "USD"
    add_column :projects, :hourly_rate_cents, :bigint
    add_column :projects, :mileage_rate_cents, :bigint

    create_table :invoices do |t|
      t.references :client, null: false, foreign_key: true, type: :integer
      t.string :number, null: false
      t.string :status, null: false, default: "draft"
      t.string :currency, limit: 3, null: false
      t.date :issued_on, null: false
      t.date :due_on, null: false
      t.decimal :tax_rate, precision: 5, scale: 2, null: false, default: 0
      t.bigint :subtotal_cents, null: false, default: 0
      t.bigint :tax_cents, null: false, default: 0
      t.bigint :total_cents, null: false, default: 0
      t.text :notes
      t.datetime :sent_at
      t.datetime :paid_at
      t.datetime :voided_at
      t.timestamps
    end
    add_index :invoices, :number, unique: true
    add_index :invoices, :status

    create_table :invoice_lines do |t|
      t.references :invoice, null: false, foreign_key: { on_delete: :cascade }
      t.references :project, null: false, foreign_key: true, type: :integer
      t.string :kind, null: false
      t.string :description, null: false
      t.decimal :quantity, precision: 12, scale: 2, null: false
      t.bigint :unit_price_cents, null: false
      t.bigint :amount_cents, null: false
      t.integer :position, null: false, default: 0
    end

    add_reference :hours, :invoice, foreign_key: true, index: true
    add_reference :mileages, :invoice, foreign_key: true, index: true
  end
end
