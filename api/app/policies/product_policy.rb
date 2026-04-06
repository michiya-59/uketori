# frozen_string_literal: true

# 品目マスタの認可ポリシー
#
# 全ロールが品目を閲覧できる。
# デフォルト: accountant以上が作成・更新、admin以上が削除。
# カスタム権限で上書き可能。
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

  # 作成: デフォルトaccountant以上
  #
  # @return [Boolean]
  def create?
    check_permission("product", "create", "accountant")
  end

  # 更新: デフォルトaccountant以上
  #
  # @return [Boolean]
  def update?
    check_permission("product", "update", "accountant")
  end

  # 削除: デフォルトadmin以上
  #
  # @return [Boolean]
  def destroy?
    check_permission("product", "destroy", "admin")
  end

  # 品目一覧のスコープ
  class Scope < ApplicationPolicy::Scope
    # @return [ActiveRecord::Relation] 同一テナントの品目
    def resolve
      scope.where(tenant_id: user.tenant_id)
    end
  end
end
