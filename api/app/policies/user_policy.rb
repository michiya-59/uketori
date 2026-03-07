# frozen_string_literal: true

# ユーザー管理の認可ポリシー
#
# owner/adminのみがユーザーの作成・更新・削除を行える。
# 全ロールがユーザー一覧・詳細を閲覧できる。
# ownerは自身を削除できない。
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

  # 作成（招待）: admin以上
  #
  # @return [Boolean]
  def create?
    admin_or_above?
  end

  # 招待: admin以上
  #
  # @return [Boolean]
  def invite?
    admin_or_above?
  end

  # 更新: admin以上（ただしownerのロール変更は不可）
  #
  # @return [Boolean]
  def update?
    return false unless admin_or_above?
    return false if record.owner? && !user.owner?

    true
  end

  # 削除: admin以上（自分自身とownerは削除不可）
  #
  # @return [Boolean]
  def destroy?
    return false unless admin_or_above?
    return false if record.id == user.id
    return false if record.owner?

    true
  end

  # ユーザー一覧のスコープ
  class Scope < ApplicationPolicy::Scope
    # @return [ActiveRecord::Relation] 同一テナントのユーザー
    def resolve
      scope.where(tenant_id: user.tenant_id)
    end
  end
end
