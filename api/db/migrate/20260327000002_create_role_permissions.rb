# frozen_string_literal: true

# ロール別権限カスタマイズテーブルを作成するマイグレーション
#
# テナントごと・ロールごとにカスタマイズされた権限設定を保存する。
# permissionsカラムはJSONB型で、"resource.action" => boolean の形式で格納する。
class CreateRolePermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :role_permissions do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :role, null: false
      t.jsonb :permissions, null: false, default: {}
      t.timestamps
    end

    add_index :role_permissions, %i[tenant_id role], unique: true
  end
end
