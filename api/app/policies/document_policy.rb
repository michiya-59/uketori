# frozen_string_literal: true

# 帳票の認可ポリシー
#
# 全ロールが帳票の閲覧を行える。
# デフォルト: sales以上が作成・更新・複製・変換、accountant以上が承認・却下・ロック。
# カスタム権限で上書き可能。
class DocumentPolicy < ApplicationPolicy
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
    check_permission("document", "create", "sales")
  end

  # 更新: デフォルトsales以上
  #
  # @return [Boolean]
  def update?
    check_permission("document", "update", "sales")
  end

  # 削除: デフォルトadmin以上
  #
  # @return [Boolean]
  def destroy?
    check_permission("document", "destroy", "admin")
  end

  # 複製: デフォルトsales以上
  #
  # @return [Boolean]
  def duplicate?
    check_permission("document", "duplicate", "sales")
  end

  # 帳票変換（見積→請求等）: デフォルトsales以上
  #
  # @return [Boolean]
  def convert?
    check_permission("document", "convert", "sales")
  end

  # 承認: デフォルトaccountant以上
  #
  # @return [Boolean]
  def approve?
    check_permission("document", "approve", "accountant")
  end

  # 却下: デフォルトaccountant以上
  #
  # @return [Boolean]
  def reject?
    check_permission("document", "reject", "accountant")
  end

  # 送付: デフォルトsales以上
  #
  # @return [Boolean]
  def send_document?
    check_permission("document", "send_document", "sales")
  end

  # ロック（確定）: デフォルトaccountant以上
  #
  # @return [Boolean]
  def lock?
    check_permission("document", "lock", "accountant")
  end

  # PDF出力: 全ロール許可
  #
  # @return [Boolean]
  def pdf?
    true
  end

  # バージョン履歴: 全ロール許可
  #
  # @return [Boolean]
  def versions?
    true
  end

  # 一括生成: デフォルトaccountant以上
  #
  # @return [Boolean]
  def bulk_generate?
    check_permission("document", "bulk_generate", "accountant")
  end

  # AI明細提案: デフォルトsales以上
  #
  # @return [Boolean]
  def ai_suggest?
    check_permission("document", "ai_suggest", "sales")
  end

  # 帳票一覧のスコープ
  class Scope < ApplicationPolicy::Scope
    # @return [ActiveRecord::Relation] 同一テナントの帳票
    def resolve
      scope.where(tenant_id: user.tenant_id)
    end
  end
end
