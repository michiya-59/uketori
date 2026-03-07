# frozen_string_literal: true

# 品目マスタの認可ポリシー
#
# 全ロールが品目を閲覧できる。
# accountant以上が作成・更新・削除を行える。
class ProductPolicy < ApplicationPolicy
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

  # 作成: accountant以上
  #
  # @return [Boolean]
  def create?
    accountant_or_above?
  end

  # 更新: accountant以上
  #
  # @return [Boolean]
  def update?
    accountant_or_above?
  end

  # 削除: admin以上
  #
  # @return [Boolean]
  def destroy?
    admin_or_above?
  end

  # 品目一覧のスコープ
  class Scope < ApplicationPolicy::Scope
    # @return [ActiveRecord::Relation] 同一テナントの品目
    def resolve
      scope.where(tenant_id: user.tenant_id)
    end
  end
end
