# frozen_string_literal: true

# 顧客管理の認可ポリシー
#
# 全ロールが顧客の閲覧を行える。
# デフォルト: sales以上が作成・更新、admin以上が削除。
# カスタム権限で上書き可能。
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

  # 作成: デフォルトsales以上
  #
  # @return [Boolean]
  def create?
    check_permission("customer", "create", "sales")
  end

  # 更新: デフォルトsales以上
  #
  # @return [Boolean]
  def update?
    check_permission("customer", "update", "sales")
  end

  # 削除: デフォルトadmin以上
  #
  # @return [Boolean]
  def destroy?
    check_permission("customer", "destroy", "admin")
  end

  # 顧客の帳票一覧表示: 全ロール許可
  #
  # @return [Boolean]
  def documents?
    true
  end

  # 顧客の信用履歴表示: デフォルトaccountant以上
  #
  # @return [Boolean]
  def credit_history?
    check_permission("customer", "credit_history", "accountant")
  end

  # インボイス番号検証: デフォルトsales以上
  #
  # @return [Boolean]
  def verify_invoice_number?
    check_permission("customer", "verify_invoice_number", "sales")
  end

  # 顧客一覧のスコープ
  class Scope < ApplicationPolicy::Scope
    # @return [ActiveRecord::Relation] 同一テナントの顧客
    def resolve
      scope.where(tenant_id: user.tenant_id)
    end
  end
end
