# frozen_string_literal: true

# 信用スコア履歴モデル
#
# 顧客の信用スコアの推移を時系列で記録する。
# スコアの変動理由やファクターを保持し、分析に利用される。
#
# @example 信用スコア履歴の作成
#   CreditScoreHistory.create!(
#     tenant: tenant,
#     customer: customer,
#     score: 75,
#     calculated_at: Time.current
#   )
class CreditScoreHistory < ApplicationRecord
  include TenantScoped

  belongs_to :tenant
  belongs_to :customer

  validates :score, presence: true, numericality: { in: 0..100 }
  validates :calculated_at, presence: true
end
