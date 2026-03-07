class CreateRecurringRules < ActiveRecord::Migration[8.0]
  def change
    create_table :recurring_rules do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: { to_table: :customers }
      t.references :project, foreign_key: { to_table: :projects }
      t.string :name, limit: 255, null: false
      t.string :frequency, limit: 10, null: false, default: "monthly"
      t.integer :generation_day, null: false, default: 1
      t.integer :issue_day, null: false, default: 1
      t.date :next_generation_date, null: false
      t.jsonb :template_items, null: false, default: "[]"
      t.boolean :auto_send, null: false, default: false
      t.boolean :is_active, null: false, default: true
      t.date :start_date, null: false
      t.date :end_date

      t.timestamps
    end
  end
end
