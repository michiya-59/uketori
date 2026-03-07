# frozen_string_literal: true

# 顧客統計更新ジョブ
#
# 毎日3:00に実行され、全顧客の統計情報（平均支払日数・遅延率・未回収残高）を再計算する。
#
# @example SolidQueue recurring schedule
#   customer_stats_update:
#     class: CustomerStatsUpdateJob
#     schedule: "0 3 * * *"
class CustomerStatsUpdateJob < ApplicationJob
  queue_as :default

  # @return [void]
  def perform
    Customer.active.find_each do |customer|
      update_stats!(customer)
    rescue StandardError => e
      Rails.logger.error("CustomerStatsUpdateJob failed for customer #{customer.id}: #{e.message}")
    end
  end

  private

  # 顧客の統計情報を更新する
  #
  # @param customer [Customer]
  # @return [void]
  def update_stats!(customer)
    invoices = customer.documents.active.where(document_type: "invoice")

    # 平均支払日数
    paid_invoices = invoices.where(payment_status: "paid").where.not(due_date: nil)
    if paid_invoices.any?
      total_days = paid_invoices.sum do |inv|
        last_payment = inv.payment_records.order(:payment_date).last
        next 0 unless last_payment

        (last_payment.payment_date - inv.issue_date).to_i
      end
      avg_days = total_days.to_f / paid_invoices.count
    end

    # 遅延率
    total_with_due = invoices.where.not(due_date: nil).count
    late_count = invoices.where(payment_status: %w[overdue bad_debt]).count
    late_rate = total_with_due > 0 ? (late_count.to_f / total_with_due * 100) : 0.0

    # 未回収残高
    outstanding = invoices.where(payment_status: %w[unpaid partial overdue])
                          .sum(:remaining_amount)

    customer.update_columns(
      avg_payment_days: avg_days || 0,
      late_payment_rate: late_rate,
      total_outstanding: outstanding
    )
  end
end
