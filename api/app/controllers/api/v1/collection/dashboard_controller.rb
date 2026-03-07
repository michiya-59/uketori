# frozen_string_literal: true

module Api
  module V1
    module Collection
      # 回収ダッシュボードコントローラー
      #
      # 回収KPI、エイジング分析、予測データの集計エンドポイントを提供する。
      class DashboardController < BaseController
        # ダッシュボードKPIを返す
        #
        # @return [void]
        def dashboard
          invoices = current_tenant.documents.active.where(document_type: "invoice")

          render json: {
            outstanding_total: invoices.where(payment_status: %w[unpaid partial overdue]).sum(:remaining_amount),
            overdue_amount: invoices.where(payment_status: "overdue").sum(:remaining_amount),
            overdue_count: invoices.where(payment_status: "overdue").count,
            paid_this_month: invoices.where(payment_status: "paid")
                                     .where("updated_at >= ?", Date.current.beginning_of_month)
                                     .sum(:total_amount),
            collection_rate: calculate_collection_rate(invoices),
            avg_dso: calculate_avg_dso(invoices),
            aging_summary: calculate_aging_summary(invoices),
            at_risk_customers: at_risk_customers,
            monthly_trend: monthly_trend(invoices),
            unmatched_count: current_tenant.bank_statements.unmatched.count
          }
        end

        # エイジングレポートを返す
        #
        # @return [void]
        def aging_report
          customers = current_tenant.customers.active
                                              .includes(:documents)
                                              .order(total_outstanding: :desc)
                                              .page(page_param).per(per_page_param)

          render json: {
            customers: customers.map { |c| serialize_aging_customer(c) },
            meta: pagination_meta(customers)
          }
        end

        # 入金予測を返す
        #
        # @return [void]
        def forecast
          invoices = current_tenant.documents.active
                                   .where(document_type: "invoice")
                                   .where(payment_status: %w[unpaid partial overdue])
                                   .where.not(due_date: nil)
                                   .order(:due_date)

          weeks = (0..11).map do |i|
            start_date = Date.current + (i * 7)
            end_date = start_date + 6
            amount = invoices.where(due_date: start_date..end_date).sum(:remaining_amount)
            { week_start: start_date, week_end: end_date, expected_amount: amount }
          end

          render json: { forecast: weeks }
        end

        private

        # 回収率を計算する（当月）
        #
        # @param invoices [ActiveRecord::Relation]
        # @return [Float]
        def calculate_collection_rate(invoices)
          month_start = Date.current.beginning_of_month
          issued = invoices.where("issue_date >= ?", month_start).sum(:total_amount)
          return 0.0 if issued.zero?

          collected = invoices.where("issue_date >= ?", month_start).sum(:paid_amount)
          (collected.to_f / issued * 100).round(1)
        end

        # 平均DSO（売掛金回転日数）を計算する
        #
        # @param invoices [ActiveRecord::Relation]
        # @return [Float]
        def calculate_avg_dso(invoices)
          paid = invoices.where(payment_status: "paid")
                         .where("updated_at >= ?", 6.months.ago)
          return 0.0 if paid.empty?

          total_days = paid.sum do |inv|
            last_payment = inv.payment_records.order(:payment_date).last
            next 0 unless last_payment

            (last_payment.payment_date - inv.issue_date).to_i
          end

          (total_days.to_f / paid.count).round(1)
        end

        # エイジングサマリーを計算する
        #
        # @param invoices [ActiveRecord::Relation]
        # @return [Hash]
        def calculate_aging_summary(invoices)
          overdue = invoices.where(payment_status: %w[unpaid partial overdue])
                            .where("due_date < ?", Date.current)
          {
            current: invoices.where(payment_status: %w[unpaid partial])
                             .where("due_date >= ?", Date.current).sum(:remaining_amount),
            days_1_30: overdue.where("due_date >= ?", 30.days.ago).sum(:remaining_amount),
            days_31_60: overdue.where("due_date >= ? AND due_date < ?", 60.days.ago, 30.days.ago).sum(:remaining_amount),
            days_61_90: overdue.where("due_date >= ? AND due_date < ?", 90.days.ago, 60.days.ago).sum(:remaining_amount),
            days_over_90: overdue.where("due_date < ?", 90.days.ago).sum(:remaining_amount)
          }
        end

        # リスク顧客一覧を返す
        #
        # @return [Array<Hash>]
        def at_risk_customers
          current_tenant.customers.active
                        .where("credit_score < 50 OR total_outstanding > 0")
                        .order(:credit_score)
                        .limit(10)
                        .map do |c|
            {
              id: c.uuid,
              company_name: c.company_name,
              credit_score: c.credit_score,
              total_outstanding: c.total_outstanding,
              has_overdue: c.documents.active.where(payment_status: "overdue").exists?
            }
          end
        end

        # 月次トレンドを返す（過去6ヶ月）
        #
        # @param invoices [ActiveRecord::Relation]
        # @return [Array<Hash>]
        def monthly_trend(invoices)
          (0..5).map do |i|
            month_start = (Date.current - i.months).beginning_of_month
            month_end = month_start.end_of_month
            {
              month: month_start.strftime("%Y-%m"),
              invoiced: invoices.where(issue_date: month_start..month_end).sum(:total_amount),
              collected: invoices.where(issue_date: month_start..month_end).sum(:paid_amount)
            }
          end.reverse
        end

        # エイジングレポート用の顧客シリアライズ
        #
        # @param customer [Customer]
        # @return [Hash]
        def serialize_aging_customer(customer)
          invoices = customer.documents.active.where(document_type: "invoice")
                             .where(payment_status: %w[unpaid partial overdue])
          overdue = invoices.where("due_date < ?", Date.current)

          {
            id: customer.uuid,
            company_name: customer.company_name,
            credit_score: customer.credit_score,
            current: invoices.where("due_date >= ?", Date.current).sum(:remaining_amount),
            days_1_30: overdue.where("due_date >= ?", 30.days.ago).sum(:remaining_amount),
            days_31_60: overdue.where("due_date >= ? AND due_date < ?", 60.days.ago, 30.days.ago).sum(:remaining_amount),
            days_61_90: overdue.where("due_date >= ? AND due_date < ?", 90.days.ago, 60.days.ago).sum(:remaining_amount),
            days_over_90: overdue.where("due_date < ?", 90.days.ago).sum(:remaining_amount),
            total_outstanding: customer.total_outstanding
          }
        end
      end
    end
  end
end
