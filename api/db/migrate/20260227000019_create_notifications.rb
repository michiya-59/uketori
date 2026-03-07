class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: { to_table: :users }
      t.string :notification_type, limit: 50, null: false
      t.string :title, limit: 255, null: false
      t.text :body
      t.jsonb :data, null: false, default: "{}"
      t.boolean :is_read, null: false, default: false
      t.datetime :read_at

      t.datetime :created_at, null: false
    end
  end
end
