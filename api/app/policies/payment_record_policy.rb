# frozen_string_literal: true

# 入金管理の認可ポリシー
#
# 全ロールが入金一覧を閲覧できる。
# デフォルト: accountant以上が登録、admin以上が削除。
# カスタム権限で上書き可能。
class PaymentRecordPolicy < ApplicationPolicy
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

  # 登録: デフォルトaccountant以上
  #
  # @return [Boolean]
  def create?
    check_permission("payment_record", "create", "accountant")
  end

  # 削除: デフォルトadmin以上
  #
  # @return [Boolean]
  def destroy?
    check_permission("payment_record", "destroy", "admin")
  end

  # 入金一覧のスコープ
  class Scope < ApplicationPolicy::Scope
    # @return [ActiveRecord::Relation] 同一テナントの入金
    def resolve
      scope.where(tenant_id: user.tenant_id)
    end
  end
end
