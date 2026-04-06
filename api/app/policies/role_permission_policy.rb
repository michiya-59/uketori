# frozen_string_literal: true

# ロール権限設定の認可ポリシー
#
# owner/admin以上が権限設定を閲覧・編集できる。
# adminはadmin/ownerの権限を編集できない。
class RolePermissionPolicy < ApplicationPolicy
  # 一覧表示: admin以上
  #
  # @return [Boolean]
  def index?
    admin_or_above?
  end

  # 更新: admin以上（ただしadminは自身のロールとownerの権限を編集不可）
  #
  # @return [Boolean]
  def update?
    return false unless admin_or_above?
    return true if user.owner?

    target_role = record.is_a?(RolePermission) ? record.role : record.to_s
    !%w[owner admin].include?(target_role)
  end

  # リセット: updateと同じ権限
  #
  # @return [Boolean]
  def reset?
    update?
  end
end
