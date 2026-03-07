# frozen_string_literal: true

# 顧客管理の認可ポリシー
#
# 全ロールが顧客の閲覧を行える。
# sales以上が作成・更新を行える。
# admin以上が削除を行える。
class CustomerPolicy < ApplicationPolicy
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

  # 顧客の帳票一覧表示: 全ロール許可
  #
  # @return [Boolean]
  def documents?
    true
  end

  # 顧客の信用履歴表示: accountant以上
  #
  # @return [Boolean]
  def credit_history?
    accountant_or_above?
  end

  # インボイス番号検証: sales以上
  #
  # @return [Boolean]
  def verify_invoice_number?
    sales_or_above?
  end

  # 顧客一覧のスコープ
  class Scope < ApplicationPolicy::Scope
    # @return [ActiveRecord::Relation] 同一テナントの顧客
    def resolve
      scope.where(tenant_id: user.tenant_id)
    end
  end
end
