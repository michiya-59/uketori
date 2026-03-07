# frozen_string_literal: true

# 書類モデル
#
# 見積書・発注書・請求書・領収書など各種ビジネス書類を管理する。
# 書類の種別ごとにステータス管理・入金ステータス管理を行い、
# 明細行やバージョン履歴と紐付ける。
#
# @example 請求書の作成
#   Document.create!(
#     tenant: tenant,
#     customer: customer,
#     created_by_user: user,
#     document_type: "invoice",
#     document_number: "INV-2026-001",
#     status: "draft",
#     issue_date: Date.current
#   )
class Document < ApplicationRecord
  include TenantScoped
  include UuidFindable
  include SoftDeletable

  belongs_to :tenant
  belongs_to :project, optional: true
  belongs_to :customer
  belongs_to :created_by_user, class_name: "User"
  belongs_to :parent_document, class_name: "Document", optional: true
  belongs_to :recurring_rule, optional: true
  has_many :document_items, dependent: :destroy
  has_many :document_versions, dependent: :destroy
  has_many :payment_records
  has_many :dunning_logs

  accepts_nested_attributes_for :document_items, allow_destroy: true

  before_validation :set_default_payment_status, on: :create

  # 書類種別の一覧
  TYPES = %w[estimate purchase_order order_confirmation delivery_note invoice receipt].freeze

  # 書類ステータスの一覧
  STATUSES = %w[draft approved sent accepted rejected cancelled locked].freeze

  # 入金ステータスの一覧
  PAYMENT_STATUSES = %w[unpaid partial paid overdue bad_debt].freeze

  validates :document_type, inclusion: { in: TYPES }
  validates :document_number, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :payment_status, inclusion: { in: PAYMENT_STATUSES }, allow_nil: true
  validates :issue_date, presence: true

  # @!method self.invoices
  #   請求書のみを取得するスコープ
  #   @return [ActiveRecord::Relation] document_typeが"invoice"のレコード
  scope :invoices, -> { where(document_type: "invoice") }

  # @!method self.estimates
  #   見積書のみを取得するスコープ
  #   @return [ActiveRecord::Relation] document_typeが"estimate"のレコード
  scope :estimates, -> { where(document_type: "estimate") }

  # @!method self.by_type(type)
  #   指定された書類種別で絞り込むスコープ
  #   @param type [String] 書類種別（TYPESに含まれる値）
  #   @return [ActiveRecord::Relation] 指定種別のレコード
  scope :by_type, ->(type) { where(document_type: type) }

  # @!method self.overdue
  #   支払い期限超過の請求書を取得するスコープ
  #   @return [ActiveRecord::Relation] 期限超過の請求書
  scope :overdue, -> { invoices.where(payment_status: "overdue") }

  # @!method self.unpaid
  #   未入金（部分入金・期限超過含む）の請求書を取得するスコープ
  #   @return [ActiveRecord::Relation] 未入金の請求書
  scope :unpaid, -> { invoices.where(payment_status: %w[unpaid partial overdue]) }

  # 書類が請求書かを判定する
  #
  # @return [Boolean] 請求書の場合はtrue
  def invoice?
    document_type == "invoice"
  end

  # 書類がロック済みかを判定する
  #
  # @return [Boolean] ロック済みの場合はtrue
  def locked?
    locked_at.present?
  end

  private

  # 請求書の作成時にpayment_statusを初期化する
  #
  # @return [void]
  def set_default_payment_status
    return unless invoice?

    self.payment_status = "unpaid" if payment_status.blank?
    self.remaining_amount = total_amount if remaining_amount.blank? || remaining_amount.zero?
  end

  public

  # 明細行から金額を再計算する
  #
  # document_itemsの合計からsubtotal・tax_amount・total_amount・remaining_amountを
  # 再計算して保存する。
  #
  # @return [Boolean] 更新に成功した場合はtrue
  # @raise [ActiveRecord::RecordInvalid] バリデーションエラー時
  def recalculate_amounts!
    items = document_items.where(item_type: "normal")
    calculated_subtotal = items.sum(:amount)
    calculated_tax = items.sum(:tax_amount)
    calculated_total = calculated_subtotal + calculated_tax
    paid = payment_records.sum(:amount)

    update!(
      subtotal: calculated_subtotal,
      tax_amount: calculated_tax,
      total_amount: calculated_total,
      paid_amount: paid,
      remaining_amount: calculated_total - paid
    )
  end
end
