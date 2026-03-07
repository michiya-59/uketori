class CreateDocumentItems < ActiveRecord::Migration[8.0]
  def change
    create_table :document_items do |t|
      t.references :document, null: false, foreign_key: true
      t.references :product, foreign_key: { to_table: :products }
      t.integer :sort_order, null: false, default: 0
      t.string :item_type, limit: 10, null: false, default: "normal"
      t.string :name, limit: 255, null: false
      t.text :description
      t.decimal :quantity, precision: 15, scale: 4, null: false, default: 1
      t.string :unit, limit: 20
      t.bigint :unit_price, null: false, default: 0
      t.bigint :amount, null: false, default: 0
      t.decimal :tax_rate, precision: 5, scale: 2, null: false, default: 10.00
      t.string :tax_rate_type, limit: 20, null: false, default: "standard"
      t.bigint :tax_amount, null: false, default: 0
    end
  end
end
