class CreatePaymentRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :payment_records do |t|
      t.column :uuid, :uuid, null: false, default: -> { "gen_random_uuid()" }
      t.references :tenant, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: { to_table: :documents }
      t.bigint :bank_statement_id
      t.bigint :amount, null: false
      t.date :payment_date, null: false
      t.string :payment_method, limit: 20, null: false, default: "bank_transfer"
      t.string :matched_by, limit: 20, null: false, default: "manual"
      t.decimal :match_confidence, precision: 3, scale: 2
      t.text :memo
      t.bigint :recorded_by_user_id, null: false

      t.timestamps
    end

    add_foreign_key :payment_records, :users, column: :recorded_by_user_id

    add_index :payment_records, [:tenant_id, :payment_date]
    add_index :payment_records, :bank_statement_id
  end
end
