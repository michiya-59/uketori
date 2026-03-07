# frozen_string_literal: true

# 案件管理の認可ポリシー
#
# 全ロールが案件の閲覧を行える。
# sales以上が作成・更新を行える。
# admin以上が削除を行える。
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

  # 作成: sales以上
  #
  # @return [Boolean]
  def create?
    sales_or_above?
  end

  # 更新: sales以上
  #
  # @return [Boolean]
  def update?
    sales_or_above?
  end

  # 削除: admin以上
  #
  # @return [Boolean]
  def destroy?
    admin_or_above?
  end

  # ステータス変更: sales以上
  #
  # @return [Boolean]
  def status?
    sales_or_above?
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
