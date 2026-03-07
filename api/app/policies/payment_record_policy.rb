# frozen_string_literal: true

# 入金管理の認可ポリシー
#
# 全ロールが入金一覧を閲覧できる。
# accountant以上が入金の登録・削除を行える。
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

  # 登録: accountant以上
  #
  # @return [Boolean]
  def create?
    accountant_or_above?
  end

  # 削除: admin以上
  #
  # @return [Boolean]
  def destroy?
    admin_or_above?
  end

  # 入金一覧のスコープ
  class Scope < ApplicationPolicy::Scope
    # @return [ActiveRecord::Relation] 同一テナントの入金
    def resolve
      scope.where(tenant_id: user.tenant_id)
    end
  end
end
