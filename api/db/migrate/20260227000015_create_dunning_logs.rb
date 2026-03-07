class CreateDunningLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :dunning_logs do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: { to_table: :documents }
      t.references :dunning_rule, null: false, foreign_key: { to_table: :dunning_rules }
      t.references :customer, null: false, foreign_key: { to_table: :customers }
      t.string :action_type, limit: 20, null: false
      t.string :sent_to_email, limit: 255
      t.string :email_subject, limit: 255
      t.text :email_body
      t.string :status, limit: 20, null: false
      t.integer :overdue_days, null: false
      t.bigint :remaining_amount, null: false

      t.datetime :created_at, null: false
    end
  end
end
