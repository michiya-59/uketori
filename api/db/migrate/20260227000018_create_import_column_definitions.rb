class CreateImportColumnDefinitions < ActiveRecord::Migration[8.0]
  def change
    create_table :import_column_definitions do |t|
      t.string :source_type, limit: 30, null: false
      t.string :source_column_name, limit: 255, null: false
      t.string :target_table, limit: 50, null: false
      t.string :target_column, limit: 50, null: false
      t.string :transform_rule, limit: 50
      t.boolean :is_required, null: false, default: false
    end
  end
end
