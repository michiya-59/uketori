# 顧客テーブルを作成するマイグレーション
class CreateCustomers < ActiveRecord::Migration[8.0]
  def change
    create_table :customers do |t|
      t.column :uuid, :uuid, null: false, default: -> { "gen_random_uuid()" }
      t.references :tenant, null: false, foreign_key: true
      t.column :customer_type, :string, limit: 10, null: false, default: "client"
      t.column :company_name, :string, limit: 255, null: false
      t.column :company_name_kana, :string, limit: 255
      t.column :department, :string, limit: 100
      t.column :title, :string, limit: 50
      t.column :contact_name, :string, limit: 100
      t.column :email, :string, limit: 255
      t.column :phone, :string, limit: 20
      t.column :fax, :string, limit: 20
      t.column :postal_code, :string, limit: 8
      t.column :prefecture, :string, limit: 10
      t.column :city, :string, limit: 100
      t.column :address_line1, :string, limit: 255
      t.column :address_line2, :string, limit: 255
      t.column :invoice_registration_number, :string, limit: 14
      t.column :invoice_number_verified, :boolean, null: false, default: false
      t.column :invoice_number_verified_at, :datetime
      t.column :payment_terms_days, :integer
      t.column :default_tax_rate, :decimal, precision: 5, scale: 2
      t.column :bank_name, :string, limit: 100
      t.column :bank_branch_name, :string, limit: 100
      t.column :bank_account_type, :integer, limit: 2
      t.column :bank_account_number, :string, limit: 10
      t.column :bank_account_holder, :string, limit: 100
      t.column :tags, :jsonb, null: false, default: '[]'
      t.column :memo, :text
      t.column :credit_score, :integer
      t.column :credit_score_updated_at, :datetime
      t.column :avg_payment_days, :decimal, precision: 5, scale: 1
      t.column :late_payment_rate, :decimal, precision: 5, scale: 2
      t.column :total_outstanding, :bigint, null: false, default: 0
      t.column :imported_from, :string, limit: 50
      t.column :external_id, :string, limit: 255

      t.timestamps
      t.column :deleted_at, :datetime

      t.index :uuid, unique: true
      t.index [:tenant_id, :deleted_at]
      t.index [:tenant_id, :credit_score]
      t.index [:tenant_id, :total_outstanding], order: { total_outstanding: :desc }
      t.index [:tenant_id, :imported_from, :external_id]
    end
  end
end
