# 商品テーブルを作成するマイグレーション
class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.references :tenant, null: false, foreign_key: true
      t.column :code, :string, limit: 50
      t.column :name, :string, limit: 255, null: false
      t.column :description, :text
      t.column :unit, :string, limit: 20
      t.column :unit_price, :bigint
      t.column :tax_rate, :decimal, precision: 5, scale: 2
      t.column :tax_rate_type, :string, limit: 20, null: false, default: "standard"
      t.column :category, :string, limit: 100
      t.column :sort_order, :integer, null: false, default: 0
      t.column :is_active, :boolean, null: false, default: true

      t.timestamps
    end
  end
end
