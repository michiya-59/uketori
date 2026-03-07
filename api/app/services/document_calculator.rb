# frozen_string_literal: true

# 帳票の金額を計算するサービス
#
# インボイス制度対応の税率別集計を含む金額計算を行う。
# 明細行ごとの金額・税額計算、税率別サマリー生成、
# 小計・税額・合計・残額の算出を提供する。
#
# @example
#   DocumentCalculator.call(document)
class DocumentCalculator
  class << self
    # 帳票の金額を再計算して保存する
    #
    # @param document [Document] 対象帳票
    # @return [Document] 再計算済みの帳票
    def call(document)
      new(document).calculate!
    end
  end

  # @param document [Document]
  def initialize(document)
    @document = document
  end

  # 金額を計算して帳票を更新する
  #
  # @return [Document] 更新済みの帳票
  def calculate!
    calculate_item_amounts!
    summary = build_tax_summary
    subtotal = summary.sum { |s| s[:subtotal] }
    tax = summary.sum { |s| s[:tax] }
    total = subtotal + tax
    paid = @document.payment_records.sum(:amount)

    @document.update!(
      subtotal: subtotal,
      tax_amount: tax,
      total_amount: total,
      tax_summary: summary,
      paid_amount: paid,
      remaining_amount: total - paid
    )

    @document
  end

  private

  # 各明細行の金額を計算する
  #
  # @return [void]
  def calculate_item_amounts!
    @document.document_items.each do |item|
      next unless item.item_type == "normal"

      amount = (item.quantity * item.unit_price).floor
      tax_amount = (amount * item.tax_rate / 100).floor
      item.update_columns(amount: amount, tax_amount: tax_amount)
    end
  end

  # 税率別集計サマリーを構築する
  #
  # @return [Array<Hash>] 税率別の小計・税額サマリー
  def build_tax_summary
    items = @document.document_items.where(item_type: "normal")
    grouped = items.group_by(&:tax_rate)

    grouped.map do |rate, rate_items|
      subtotal = rate_items.sum(&:amount)
      tax = (subtotal * rate / 100).floor
      { rate: rate.to_f, subtotal: subtotal, tax: tax }
    end.sort_by { |s| -s[:rate] }
  end
end
