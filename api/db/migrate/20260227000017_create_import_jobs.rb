class CreateImportJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :import_jobs do |t|
      t.column :uuid, :uuid, null: false, default: -> { "gen_random_uuid()" }
      t.references :tenant, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: { to_table: :users }
      t.string :source_type, limit: 30, null: false
      t.string :status, limit: 20, null: false, default: "pending"
      t.string :file_url, limit: 500, null: false
      t.string :file_name, limit: 255, null: false
      t.bigint :file_size, null: false
      t.jsonb :parsed_data
      t.jsonb :column_mapping
      t.jsonb :preview_data
      t.jsonb :import_stats
      t.jsonb :error_details
      t.decimal :ai_mapping_confidence, precision: 3, scale: 2
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
  end
end
