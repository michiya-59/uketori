# frozen_string_literal: true

# ユーザー管理の認可ポリシー
#
# デフォルト: admin以上がユーザーの作成・更新・削除を行える。
# 全ロールがユーザー一覧・詳細を閲覧できる。
# ownerは自身を削除できない。ownerのロール変更はownerのみ。
# カスタム権限で上書き可能（ビジネスロジック制約は維持）。
class UserPolicy < ApplicationPolicy
  # 一覧表示: 全ロール許可
  #
  # @return [Boolean]
  def index?
    true
  end

  # 詳細表示: 全ロール許可
  #
  # @return [Boolean]
  def show?
    true
  end

  # 作成（招待）: デフォルトadmin以上
  #
  # @return [Boolean]
  def create?
    check_permission("user", "create", "admin")
  end

  # 招待: デフォルトadmin以上
  #
  # @return [Boolean]
  def invite?
    check_permission("user", "invite", "admin")
  end

  # 更新: デフォルトadmin以上（ただしownerのロール変更は不可）
  #
  # @return [Boolean]
  def update?
    return false if record.owner? && !user.owner?

    check_permission("user", "update", "admin")
  end

  # 削除: デフォルトadmin以上（自分自身とownerは削除不可）
  #
  # @return [Boolean]
  def destroy?
    return false if record.id == user.id
    return false if record.owner?

    check_permission("user", "destroy", "admin")
  end

  # ユーザー一覧のスコープ
  class Scope < ApplicationPolicy::Scope
    # @return [ActiveRecord::Relation] 同一テナントのユーザー
    def resolve
      scope.where(tenant_id: user.tenant_id)
    end
  end
end
