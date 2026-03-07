class CreateBankStatements < ActiveRecord::Migration[8.0]
  def change
    create_table :bank_statements do |t|
      t.references :tenant, null: false, foreign_key: true
      t.date :transaction_date, null: false
      t.date :value_date
      t.string :description, limit: 500, null: false
      t.string :payer_name, limit: 255
      t.bigint :amount, null: false
      t.bigint :balance
      t.string :bank_name, limit: 100
      t.string :account_number, limit: 20
      t.boolean :is_matched, null: false, default: false
      t.bigint :matched_document_id
      t.bigint :ai_suggested_document_id
      t.decimal :ai_match_confidence, precision: 3, scale: 2
      t.text :ai_match_reason
      t.string :import_batch_id, limit: 50, null: false
      t.jsonb :raw_data

      t.timestamps
    end

    add_foreign_key :bank_statements, :documents, column: :matched_document_id

    add_index :bank_statements, [:tenant_id, :is_matched, :transaction_date],
              where: "is_matched = false"
    add_index :bank_statements, [:tenant_id, :transaction_date]
    add_index :bank_statements, :import_batch_id
  end
end
