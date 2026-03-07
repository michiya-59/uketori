class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs do |t|
      t.references :tenant, null: false, foreign_key: true
      t.bigint :user_id
      t.string :action, limit: 50, null: false
      t.string :resource_type, limit: 50, null: false
      t.bigint :resource_id
      t.jsonb :changes_data
      t.inet :ip_address
      t.string :user_agent, limit: 500

      t.datetime :created_at, null: false
    end

    add_foreign_key :audit_logs, :users, column: :user_id
  end
end
