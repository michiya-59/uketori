# frozen_string_literal: true

# 銀行明細の認可ポリシー
#
# 全ロールが明細を閲覧できる。
# accountant以上がインポート・マッチング操作を行える。
class BankStatementPolicy < ApplicationPolicy
  # 一覧表示: 全ロール許可
  #
  # @return [Boolean]
  def index?
    true
  end

  # インポート: accountant以上
  #
  # @return [Boolean]
  def import?
    accountant_or_above?
  end

  # 未マッチ一覧: 全ロール許可
  #
  # @return [Boolean]
  def unmatched?
    true
  end

  # 手動マッチング: accountant以上
  #
  # @return [Boolean]
  def match?
    accountant_or_above?
  end

  # AI自動マッチング: accountant以上
  #
  # @return [Boolean]
  def ai_match?
    accountant_or_above?
  end

  # AIマッチング候補提案: accountant以上
  #
  # @return [Boolean]
  def ai_suggest?
    accountant_or_above?
  end

  # 銀行明細一覧のスコープ
  class Scope < ApplicationPolicy::Scope
    # @return [ActiveRecord::Relation] 同一テナントの銀行明細
    def resolve
      scope.where(tenant_id: user.tenant_id)
    end
  end
end
