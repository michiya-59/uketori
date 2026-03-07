# frozen_string_literal: true

# 督促ルールの認可ポリシー
#
# 全ロールが督促ルールを閲覧できる。
# accountant以上がルールの作成・更新を行える。
# admin以上がルールの削除を行える。
class DunningRulePolicy < ApplicationPolicy
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

  # 督促実行: accountant以上
  #
  # @return [Boolean]
  def execute?
    accountant_or_above?
  end

  # 督促ルール一覧のスコープ
  class Scope < ApplicationPolicy::Scope
    # @return [ActiveRecord::Relation] 同一テナントの督促ルール
    def resolve
      scope.where(tenant_id: user.tenant_id)
    end
  end
end
