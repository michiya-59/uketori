# frozen_string_literal: true

# 入金記録モデル
#
# 請求書に対する入金情報を管理する。
# 銀行振込・現金・クレジットカード等の入金方法と、
# 手動・AI自動・AI提案のマッチング種別を持つ。
#
# @example 入金記録の作成
#   PaymentRecord.create!(
#     tenant: tenant,
#     document: invoice,
#     recorded_by_user: user,
#     amount: 100_000,
#     payment_date: Date.current,
#     payment_method: "bank_transfer",
#     matched_by: "manual"
#   )
class PaymentRecord < ApplicationRecord
  include TenantScoped
  include UuidFindable

  belongs_to :tenant
  belongs_to :document
  belongs_to :bank_statement, optional: true
  belongs_to :recorded_by_user, class_name: "User"

  # 支払い方法の一覧
  METHODS = %w[bank_transfer cash credit_card other].freeze

  # マッチング種別の一覧
  MATCH_TYPES = %w[manual ai_auto ai_suggested].freeze

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_date, presence: true
  validates :payment_method, inclusion: { in: METHODS }
  validates :matched_by, inclusion: { in: MATCH_TYPES }

  after_create :update_document_payment!
  after_destroy :update_document_payment!

  private

  # 関連する書類の入金情報を再計算する
  #
  # 書類に紐付く全入金記録の合計額からpaid_amount・remaining_amount・payment_statusを
  # 再計算して書類を更新する。
  #
  # @return [void]
  def update_document_payment!
    doc = document
    total_paid = doc.payment_records.sum(:amount)
    total_amount = doc.total_amount || 0
    remaining = total_amount - total_paid

    payment_status = if total_paid >= total_amount
                       "paid"
                     elsif total_paid.positive?
                       "partial"
                     elsif doc.due_date.present? && doc.due_date < Date.current
                       "overdue"
                     else
                       "unpaid"
                     end

    doc.update!(
      paid_amount: total_paid,
      remaining_amount: remaining,
      payment_status: payment_status
    )
  end
end
