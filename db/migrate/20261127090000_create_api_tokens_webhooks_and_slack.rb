# Phase 2, step 4: personal API tokens, webhooks and Slack. Tenant tables,
# except slack_workspaces, which maps a Slack team to an account and lives in
# the public schema (excluded model).
class CreateApiTokensWebhooksAndSlack < ActiveRecord::Migration[8.1]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :integer
      t.string :name, null: false
      t.string :token_digest, null: false # SHA-256; the token itself is shown once
      t.string :token_prefix, null: false # first characters, to recognise it in the list
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :api_tokens, :token_digest, unique: true

    create_table :webhook_endpoints do |t|
      t.string :url, null: false
      t.text :secret, null: false # Active Record Encryption
      t.string :events, array: true, null: false, default: []
      t.boolean :active, null: false, default: true
      t.integer :consecutive_failures, null: false, default: 0
      t.datetime :last_delivered_at
      t.integer :last_status
      t.string :last_error
      t.timestamps
    end

    add_column :users, :slack_user_id, :string
    add_index :users, :slack_user_id, unique: true

    create_table :slack_workspaces do |t|
      t.string :team_id, null: false
      t.string :subdomain, null: false
      t.timestamps
    end
    add_index :slack_workspaces, :team_id, unique: true
    add_index :slack_workspaces, :subdomain, unique: true
  end
end
