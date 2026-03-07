# frozen_string_literal: true

# 書類明細行モデル
#
# 書類（見積書・請求書等）の明細行を管理する。
# 通常行・小計行・値引き行・セクションヘッダーの種別を持つ。
#
# @example 明細行の作成
#   DocumentItem.create!(
#     document: document,
#     name: "コンサルティング費用",
#     item_type: "normal",
#     quantity: 2,
#     unit_price: 50_000,
#     tax_rate: 10.0,
#     tax_rate_type: "standard"
#   )
class DocumentItem < ApplicationRecord
  belongs_to :document
  belongs_to :product, optional: true

  # 明細行種別の一覧
  ITEM_TYPES = %w[normal subtotal discount section_header].freeze

  validates :name, presence: true
  validates :item_type, inclusion: { in: ITEM_TYPES }
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :unit_price, numericality: true
  validates :tax_rate, numericality: { greater_than_or_equal_to: 0 }
  validates :tax_rate_type, inclusion: { in: %w[standard reduced exempt] }

  before_validation :calculate_amount

  private

  # 金額と税額を計算する
  #
  # 数量と単価から金額（税抜）を算出し、税率から税額を算出する。
  # 端数は切り捨て（floor）とする。
  #
  # @return [void]
  def calculate_amount
    return if quantity.nil? || unit_price.nil?

    self.amount = (quantity * unit_price).floor
    self.tax_amount = (amount * tax_rate / 100).floor if tax_rate.present?
  end
end
