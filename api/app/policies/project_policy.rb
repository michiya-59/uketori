# frozen_string_literal: true

# 案件管理の認可ポリシー
#
# 全ロールが案件の閲覧を行える。
# デフォルト: sales以上が作成・更新、admin以上が削除。
# カスタム権限で上書き可能。
class ProjectPolicy < ApplicationPolicy
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

  # 作成: デフォルトsales以上
  #
  # @return [Boolean]
  def create?
    check_permission("project", "create", "sales")
  end

  # 更新: デフォルトsales以上
  #
  # @return [Boolean]
  def update?
    check_permission("project", "update", "sales")
  end

  # 削除: デフォルトadmin以上
  #
  # @return [Boolean]
  def destroy?
    check_permission("project", "destroy", "admin")
  end

  # ステータス変更: デフォルトsales以上
  #
  # @return [Boolean]
  def status?
    check_permission("project", "status", "sales")
  end

  # 案件の帳票一覧: 全ロール許可
  #
  # @return [Boolean]
  def documents?
    true
  end

  # パイプライン表示: 全ロール許可
  #
  # @return [Boolean]
  def pipeline?
    true
  end

  # 案件一覧のスコープ
  class Scope < ApplicationPolicy::Scope
    # @return [ActiveRecord::Relation] 同一テナントの案件
    def resolve
      scope.where(tenant_id: user.tenant_id)
    end
  end
end
