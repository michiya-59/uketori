# frozen_string_literal: true

# テナント設定の認可ポリシー
#
# 全ロールがテナント情報を閲覧できる。
# デフォルト: admin以上がテナント設定を更新できる。
# カスタム権限で上書き可能。
class TenantPolicy < ApplicationPolicy
  # 詳細表示: 全ロール許可
  #
  # @return [Boolean]
  def show?
    true
  end

  # 更新: デフォルトadmin以上
  #
  # @return [Boolean]
  def update?
    check_permission("tenant", "update", "admin")
  end
end
