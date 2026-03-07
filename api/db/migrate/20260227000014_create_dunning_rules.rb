class CreateDunningRules < ActiveRecord::Migration[8.0]
  def change
    create_table :dunning_rules do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, limit: 100, null: false
      t.integer :trigger_days_after_due, null: false
      t.string :action_type, limit: 20, null: false
      t.string :email_template_subject, limit: 255
      t.text :email_template_body
      t.string :send_to, limit: 20, null: false, default: "billing_contact"
      t.string :custom_email, limit: 255
      t.boolean :is_active, null: false, default: true
      t.integer :sort_order, null: false, default: 0
      t.integer :max_dunning_count, null: false, default: 3
      t.integer :interval_days, null: false, default: 7
      t.bigint :escalation_rule_id

      t.timestamps
    end

    add_foreign_key :dunning_rules, :dunning_rules, column: :escalation_rule_id
  end
end
