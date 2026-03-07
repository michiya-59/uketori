# frozen_string_literal: true

# 銀行明細モデル
#
# インポートされた銀行取引明細を管理する。
# 請求書との自動マッチングや手動マッチングに使用される。
#
# @example 銀行明細の作成
#   BankStatement.create!(
#     tenant: tenant,
#     transaction_date: Date.current,
#     description: "株式会社サンプル 振込",
#     amount: 100_000,
#     import_batch_id: "batch-2026-001",
#     is_matched: false
#   )
class BankStatement < ApplicationRecord
  include TenantScoped

  belongs_to :tenant
  belongs_to :matched_document, class_name: "Document", optional: true
  belongs_to :ai_suggested_document, class_name: "Document", optional: true
  has_many :payment_records

  validates :transaction_date, presence: true
  validates :description, presence: true
  validates :amount, presence: true
  validates :import_batch_id, presence: true

  # @!method self.unmatched
  #   未マッチングの明細を取得するスコープ
  #   @return [ActiveRecord::Relation] is_matchedがfalseのレコード
  scope :unmatched, -> { where(is_matched: false) }

  # @!method self.matched
  #   マッチング済みの明細を取得するスコープ
  #   @return [ActiveRecord::Relation] is_matchedがtrueのレコード
  scope :matched, -> { where(is_matched: true) }
end
