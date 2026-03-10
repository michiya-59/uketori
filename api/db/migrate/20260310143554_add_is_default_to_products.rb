# 品目にデフォルトフラグを追加するマイグレーション
#
# 業種テンプレートから自動作成された品目を区別するために使用する。
# is_default=true の品目はユーザーによる編集・削除を禁止する。
class AddIsDefaultToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :is_default, :boolean, null: false, default: false
  end
end
