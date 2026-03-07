# 業種テンプレートテーブルを作成するマイグレーション
class CreateIndustryTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :industry_templates do |t|
      t.column :code, :string, limit: 50, null: false
      t.column :name, :string, limit: 100, null: false
      t.column :labels, :jsonb, null: false, default: '{}'
      t.column :default_products, :jsonb, null: false, default: '[]'
      t.column :default_statuses, :jsonb, null: false, default: '[]'
      t.column :document_templates, :jsonb, null: false, default: '{}'
      t.column :tax_settings, :jsonb, null: false, default: '{}'
      t.column :sort_order, :integer, null: false, default: 0
      t.column :is_active, :boolean, null: false, default: true

      t.index :code, unique: true
    end
  end
end
