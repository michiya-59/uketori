# 顧客連絡先テーブルを作成するマイグレーション
class CreateCustomerContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :customer_contacts do |t|
      t.references :customer, null: false, foreign_key: true
      t.column :name, :string, limit: 100, null: false
      t.column :email, :string, limit: 255
      t.column :phone, :string, limit: 20
      t.column :department, :string, limit: 100
      t.column :title, :string, limit: 50
      t.column :is_primary, :boolean, null: false, default: false
      t.column :is_billing_contact, :boolean, null: false, default: false
      t.column :memo, :text

      t.timestamps
    end
  end
end
