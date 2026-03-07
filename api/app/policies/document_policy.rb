# frozen_string_literal: true

# 帳票の認可ポリシー
#
# 全ロールが帳票の閲覧を行える。
# sales以上が作成・更新・複製・変換を行える。
# accountant以上が承認・却下・ロックを行える。
# admin以上が削除を行える。
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

  # 複製: sales以上
  #
  # @return [Boolean]
  def duplicate?
    sales_or_above?
  end

  # 帳票変換（見積→請求等）: sales以上
  #
  # @return [Boolean]
  def convert?
    sales_or_above?
  end

  # 承認: accountant以上
  #
  # @return [Boolean]
  def approve?
    accountant_or_above?
  end

  # 却下: accountant以上
  #
  # @return [Boolean]
  def reject?
    accountant_or_above?
  end

  # 送付: sales以上
  #
  # @return [Boolean]
  def send_document?
    sales_or_above?
  end

  # ロック（確定）: accountant以上
  #
  # @return [Boolean]
  def lock?
    accountant_or_above?
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

  # 一括生成: accountant以上
  #
  # @return [Boolean]
  def bulk_generate?
    accountant_or_above?
  end

  # AI明細提案: sales以上
  #
  # @return [Boolean]
  def ai_suggest?
    sales_or_above?
  end

  # 帳票一覧のスコープ
  class Scope < ApplicationPolicy::Scope
    # @return [ActiveRecord::Relation] 同一テナントの帳票
    def resolve
      scope.where(tenant_id: user.tenant_id)
    end
  end
end
