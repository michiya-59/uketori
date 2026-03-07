class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :documents do |t|
      t.column :uuid, :uuid, null: false, default: -> { "gen_random_uuid()" }
      t.references :tenant, null: false, foreign_key: true
      t.references :project, foreign_key: { to_table: :projects }
      t.references :customer, null: false, foreign_key: { to_table: :customers }
      t.bigint :created_by_user_id, null: false
      t.string :document_type, limit: 20, null: false
      t.string :document_number, limit: 50, null: false
      t.string :status, limit: 20, null: false, default: "draft"
      t.integer :version, null: false, default: 1
      t.bigint :parent_document_id
      t.string :title, limit: 255
      t.date :issue_date, null: false
      t.date :due_date
      t.date :valid_until
      t.bigint :subtotal, null: false, default: 0
      t.bigint :tax_amount, null: false, default: 0
      t.bigint :total_amount, null: false, default: 0
      t.jsonb :tax_summary, null: false, default: "[]"
      t.text :notes
      t.text :internal_memo
      t.jsonb :sender_snapshot, null: false, default: "{}"
      t.jsonb :recipient_snapshot, null: false, default: "{}"
      t.string :pdf_url, limit: 500
      t.datetime :pdf_generated_at
      t.datetime :sent_at
      t.string :sent_method, limit: 20
      t.datetime :locked_at
      t.string :payment_status, limit: 20
      t.bigint :paid_amount, null: false, default: 0
      t.bigint :remaining_amount, null: false, default: 0
      t.datetime :last_dunning_at
      t.integer :dunning_count, null: false, default: 0
      t.boolean :is_recurring, null: false, default: false
      t.bigint :recurring_rule_id
      t.string :imported_from, limit: 50
      t.string :external_id, limit: 255

      t.timestamps
      t.datetime :deleted_at
    end

    add_foreign_key :documents, :users, column: :created_by_user_id
    add_foreign_key :documents, :documents, column: :parent_document_id
    add_foreign_key :documents, :recurring_rules, column: :recurring_rule_id

    add_index :documents, :uuid, unique: true
    add_index :documents, [:tenant_id, :document_type, :deleted_at]
    add_index :documents, [:tenant_id, :document_type, :document_number],
              unique: true,
              where: "deleted_at IS NULL"
    add_index :documents, [:tenant_id, :payment_status, :due_date],
              where: "document_type = 'invoice'"
    add_index :documents, [:tenant_id, :due_date],
              where: "document_type = 'invoice' AND payment_status IN ('unpaid', 'partial', 'overdue')"
    add_index :documents, [:tenant_id, :imported_from, :external_id]
  end
end
