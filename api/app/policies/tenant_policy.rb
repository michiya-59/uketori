# frozen_string_literal: true

# テナント設定の認可ポリシー
#
# 全ロールがテナント情報を閲覧できる。
# owner/adminのみがテナント設定を更新できる。
class TenantPolicy < ApplicationPolicy
  # 詳細表示: 全ロール許可
  #
  # @return [Boolean]
  def show?
    true
  end

  # 更新: admin以上
  #
  # @return [Boolean]
  def update?
    admin_or_above?
  end
end
