class CreateDocumentVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :document_versions do |t|
      t.references :document, null: false, foreign_key: true
      t.integer :version, null: false
      t.jsonb :snapshot, null: false
      t.string :pdf_url, limit: 500
      t.bigint :changed_by_user_id, null: false
      t.text :change_reason

      t.datetime :created_at, null: false
    end

    add_foreign_key :document_versions, :users, column: :changed_by_user_id
  end
end
