# frozen_string_literal: true

# 銀行明細の認可ポリシー
#
# 全ロールが明細を閲覧できる。
# デフォルト: accountant以上がインポート・マッチング操作。
# カスタム権限で上書き可能。
class BankStatementPolicy < ApplicationPolicy
  # 一覧表示: 全ロール許可
  #
  # @return [Boolean]
  def index?
    true
  end

  # インポート: デフォルトaccountant以上
  #
  # @return [Boolean]
  def import?
    check_permission("bank_statement", "import", "accountant")
  end

  # OCRプレビュー: デフォルトaccountant以上
  #
  # @return [Boolean]
  def ocr_preview?
    check_permission("bank_statement", "ocr_preview", "accountant")
  end

  # 未マッチ一覧: 全ロール許可
  #
  # @return [Boolean]
  def unmatched?
    true
  end

  # 手動マッチング: デフォルトaccountant以上
  #
  # @return [Boolean]
  def match?
    check_permission("bank_statement", "match", "accountant")
  end

  # AI自動マッチング: デフォルトaccountant以上
  #
  # @return [Boolean]
  def ai_match?
    check_permission("bank_statement", "ai_match", "accountant")
  end

  # AIマッチング候補提案: デフォルトaccountant以上
  #
  # @return [Boolean]
  def ai_suggest?
    check_permission("bank_statement", "ai_suggest", "accountant")
  end

  # 銀行明細一覧のスコープ
  class Scope < ApplicationPolicy::Scope
    # @return [ActiveRecord::Relation] 同一テナントの銀行明細
    def resolve
      scope.where(tenant_id: user.tenant_id)
    end
  end
end
