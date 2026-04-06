# frozen_string_literal: true

# ユーザーにシステム管理者フラグを追加するマイグレーション
class AddSystemAdminToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :system_admin, :boolean, default: false, null: false
  end
end
