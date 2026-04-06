# frozen_string_literal: true

# 督促ルールの認可ポリシー
#
# 全ロールが督促ルールを閲覧できる。
# デフォルト: accountant以上が作成・更新・実行、admin以上が削除。
# カスタム権限で上書き可能。
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

  # 作成: デフォルトaccountant以上
  #
  # @return [Boolean]
  def create?
    check_permission("dunning_rule", "create", "accountant")
  end

  # 更新: デフォルトaccountant以上
  #
  # @return [Boolean]
  def update?
    check_permission("dunning_rule", "update", "accountant")
  end

  # 削除: デフォルトadmin以上
  #
  # @return [Boolean]
  def destroy?
    check_permission("dunning_rule", "destroy", "admin")
  end

  # 督促実行: デフォルトaccountant以上
  #
  # @return [Boolean]
  def execute?
    check_permission("dunning_rule", "execute", "accountant")
  end

  # 督促ルール一覧のスコープ
  class Scope < ApplicationPolicy::Scope
    # @return [ActiveRecord::Relation] 同一テナントの督促ルール
    def resolve
      scope.where(tenant_id: user.tenant_id)
    end
  end
end
