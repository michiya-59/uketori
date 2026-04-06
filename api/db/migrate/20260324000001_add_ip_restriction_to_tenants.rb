# frozen_string_literal: true

# テナントにIP制限機能のカラムを追加するマイグレーション
class AddIpRestrictionToTenants < ActiveRecord::Migration[8.0]
  def change
    add_column :tenants, :ip_restriction_enabled, :boolean, default: false, null: false
    add_column :tenants, :allowed_ip_addresses, :text, array: true, default: [], null: false
  end
end
