# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_26_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "subdomain", default: "", null: false
    t.integer "owner_id", default: 0, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audits", force: :cascade do |t|
    t.integer "auditable_id"
    t.string "auditable_type"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.string "action"
    t.text "audited_changes"
    t.integer "version", default: 0
    t.string "comment"
    t.string "remote_address"
    t.string "request_uuid"
    t.datetime "created_at"
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "budget_alerts", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "kind", null: false
    t.integer "threshold", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "kind", "threshold"], name: "index_budget_alerts_on_project_id_and_kind_and_threshold", unique: true
    t.index ["project_id"], name: "index_budget_alerts_on_project_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "clients", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "description", default: ""
    t.string "logo_file_name"
    t.string "logo_content_type"
    t.integer "logo_file_size"
    t.datetime "logo_updated_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "currency", limit: 3, default: "USD", null: false
  end

  create_table "hours", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "category_id", null: false
    t.integer "user_id", null: false
    t.decimal "value", precision: 6, scale: 2, null: false
    t.date "date", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "description"
    t.boolean "billed", default: false
    t.bigint "invoice_id"
    t.index ["billed"], name: "index_hours_on_billed"
    t.index ["category_id"], name: "index_hours_on_category_id"
    t.index ["date"], name: "index_hours_on_date"
    t.index ["invoice_id"], name: "index_hours_on_invoice_id"
    t.index ["project_id"], name: "index_hours_on_project_id"
    t.index ["user_id"], name: "index_hours_on_user_id"
  end

  create_table "invoice_lines", force: :cascade do |t|
    t.bigint "invoice_id", null: false
    t.integer "project_id", null: false
    t.string "kind", null: false
    t.string "description", null: false
    t.decimal "quantity", precision: 12, scale: 2, null: false
    t.bigint "unit_price_cents", null: false
    t.bigint "amount_cents", null: false
    t.integer "position", default: 0, null: false
    t.index ["invoice_id"], name: "index_invoice_lines_on_invoice_id"
    t.index ["project_id"], name: "index_invoice_lines_on_project_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.integer "client_id", null: false
    t.string "number", null: false
    t.string "status", default: "draft", null: false
    t.string "currency", limit: 3, null: false
    t.date "issued_on", null: false
    t.date "due_on", null: false
    t.decimal "tax_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.bigint "subtotal_cents", default: 0, null: false
    t.bigint "tax_cents", default: 0, null: false
    t.bigint "total_cents", default: 0, null: false
    t.text "notes"
    t.datetime "sent_at"
    t.datetime "paid_at"
    t.datetime "voided_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_invoices_on_client_id"
    t.index ["number"], name: "index_invoices_on_number", unique: true
    t.index ["status"], name: "index_invoices_on_status"
  end

  create_table "mileages", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "user_id", null: false
    t.integer "value", null: false
    t.date "date", null: false
    t.boolean "billed", default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.bigint "invoice_id"
    t.index ["billed"], name: "index_mileages_on_billed"
    t.index ["date"], name: "index_mileages_on_date"
    t.index ["invoice_id"], name: "index_mileages_on_invoice_id"
    t.index ["project_id"], name: "index_mileages_on_project_id"
    t.index ["user_id"], name: "index_mileages_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "slug"
    t.integer "budget"
    t.boolean "billable", default: false
    t.integer "client_id"
    t.boolean "archived", default: false, null: false
    t.text "description"
    t.bigint "hourly_rate_cents"
    t.bigint "mileage_rate_cents"
    t.bigint "budget_amount_cents"
    t.index ["archived"], name: "index_projects_on_archived"
    t.index ["billable"], name: "index_projects_on_billable"
    t.index ["slug"], name: "index_projects_on_slug"
  end

  create_table "taggings", force: :cascade do |t|
    t.integer "tag_id"
    t.integer "hour_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["hour_id"], name: "index_taggings_on_hour_id"
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "slug"
    t.index ["slug"], name: "index_tags_on_slug"
  end

  create_table "timers", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "project_id", null: false
    t.integer "category_id", null: false
    t.string "description"
    t.datetime "started_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_timers_on_category_id"
    t.index ["project_id"], name: "index_timers_on_project_id"
    t.index ["user_id"], name: "index_timers_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "first_name", default: "", null: false
    t.string "last_name", default: "", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: ""
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "organization_id"
    t.string "slug"
    t.string "invitation_token"
    t.datetime "invitation_created_at"
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.integer "invitation_limit"
    t.integer "invited_by_id"
    t.string "invited_by_type"
    t.integer "invitations_count", default: 0
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invitations_count"], name: "index_users_on_invitations_count"
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["slug"], name: "index_users_on_slug"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "budget_alerts", "projects", on_delete: :cascade
  add_foreign_key "hours", "invoices"
  add_foreign_key "invoice_lines", "invoices", on_delete: :cascade
  add_foreign_key "invoice_lines", "projects"
  add_foreign_key "invoices", "clients"
  add_foreign_key "mileages", "invoices"
  add_foreign_key "timers", "categories"
  add_foreign_key "timers", "projects"
  add_foreign_key "timers", "users"
end
