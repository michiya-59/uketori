# テナントにデータ移行機能の有効フラグを追加するマイグレーション
class AddImportEnabledToTenants < ActiveRecord::Migration[8.0]
  def change
    add_column :tenants, :import_enabled, :boolean, null: false, default: false
  end
end
