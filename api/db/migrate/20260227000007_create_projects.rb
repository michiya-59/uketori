# 案件テーブルを作成するマイグレーション
class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.column :uuid, :uuid, null: false, default: -> { "gen_random_uuid()" }
      t.references :tenant, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :assigned_user, foreign_key: { to_table: :users }
      t.column :project_number, :string, limit: 50, null: false
      t.column :name, :string, limit: 255, null: false
      t.column :status, :string, limit: 30, null: false, default: "negotiation"
      t.column :probability, :integer
      t.column :amount, :bigint
      t.column :cost, :bigint
      t.column :start_date, :date
      t.column :end_date, :date
      t.column :description, :text
      t.column :tags, :jsonb, null: false, default: '[]'
      t.column :custom_fields, :jsonb, null: false, default: '{}'
      t.column :imported_from, :string, limit: 50
      t.column :external_id, :string, limit: 255

      t.timestamps
      t.column :deleted_at, :datetime

      t.index :uuid, unique: true
      t.index [:tenant_id, :status, :deleted_at]
      t.index [:tenant_id, :project_number], unique: true, where: "deleted_at IS NULL"
    end
  end
end
