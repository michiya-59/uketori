# テナントテーブルを作成するマイグレーション
class CreateTenants < ActiveRecord::Migration[8.0]
  def change
    create_table :tenants do |t|
      t.column :uuid, :uuid, null: false, default: -> { "gen_random_uuid()" }
      t.column :name, :string, limit: 255, null: false
      t.column :name_kana, :string, limit: 255
      t.column :postal_code, :string, limit: 8
      t.column :prefecture, :string, limit: 10
      t.column :city, :string, limit: 100
      t.column :address_line1, :string, limit: 255
      t.column :address_line2, :string, limit: 255
      t.column :phone, :string, limit: 20
      t.column :fax, :string, limit: 20
      t.column :email, :string, limit: 255
      t.column :website, :string, limit: 500
      t.column :invoice_registration_number, :string, limit: 14
      t.column :invoice_number_verified, :boolean, null: false, default: false
      t.column :invoice_number_verified_at, :datetime
      t.column :logo_url, :string, limit: 500
      t.column :seal_url, :string, limit: 500
      t.column :bank_name, :string, limit: 100
      t.column :bank_branch_name, :string, limit: 100
      t.column :bank_account_type, :integer, limit: 2
      t.column :bank_account_number, :string, limit: 10
      t.column :bank_account_holder, :string, limit: 100
      t.column :industry_type, :string, limit: 50, null: false, default: "general"
      t.column :fiscal_year_start_month, :integer, limit: 2, null: false, default: 4
      t.column :plan, :string, limit: 30, null: false, default: "free"
      t.column :plan_started_at, :datetime
      t.column :stripe_customer_id, :string, limit: 100
      t.column :stripe_subscription_id, :string, limit: 100
      t.column :document_sequence_format, :string, limit: 100, null: false, default: "{prefix}-{YYYY}{MM}-{SEQ}"
      t.column :default_payment_terms_days, :integer, null: false, default: 30
      t.column :default_tax_rate, :decimal, precision: 5, scale: 2, null: false, default: "10.00"
      t.column :dunning_enabled, :boolean, null: false, default: false
      t.column :timezone, :string, limit: 50, null: false, default: "Asia/Tokyo"

      t.timestamps
      t.column :deleted_at, :datetime

      t.index :uuid, unique: true
      t.index :stripe_customer_id
      t.index :deleted_at
    end
  end
end
