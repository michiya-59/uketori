# frozen_string_literal: true

# 与信スコア計算ジョブ
#
# 毎日2:00に実行され、全顧客の与信スコアを再計算する。
#
# @example SolidQueue recurring schedule
#   credit_score_calculation:
#     class: CreditScoreCalculationJob
#     schedule: "0 2 * * *"
class CreditScoreCalculationJob < ApplicationJob
  queue_as :default

  # @return [void]
  def perform
    Customer.active.find_each do |customer|
      CreditScoreCalculator.call(customer)
    rescue StandardError => e
      Rails.logger.error("CreditScoreCalculationJob failed for customer #{customer.id}: #{e.message}")
    end
  end
end
