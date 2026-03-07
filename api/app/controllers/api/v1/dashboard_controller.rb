# frozen_string_literal: true

module Api
  module V1
    # メインダッシュボードコントローラー
    #
    # KPIカード、売上推移、入金予定、最近の取引、
    # 案件パイプラインのデータを集計して返す。
    class DashboardController < BaseController
      # ダッシュボードKPIを返す
      #
      # @return [void]
      def show
        period = params[:period] || "month"
        range = period_range(period)

        invoices = current_tenant.documents.active.where(document_type: "invoice")

        render json: {
          kpi: build_kpis(invoices, range),
          alert: build_alert(invoices),
          revenue_trend: revenue_trend(invoices),
          upcoming_payments: upcoming_payments(invoices),
          recent_transactions: recent_transactions,
          pipeline: pipeline_summary,
          period: period
        }
      end

      private

      # 期間からDateRangeを返す
      #
      # @param period [String] "month", "quarter", "year"
      # @return [Range<Date>]
      def period_range(period)
        case period
        when "quarter"
          Date.current.beginning_of_quarter..Date.current.end_of_quarter
        when "year"
          Date.current.beginning_of_year..Date.current.end_of_year
        else
          Date.current.beginning_of_month..Date.current.end_of_month
        end
      end

      # 前期のRangeを返す
      #
      # @param period [String]
      # @return [Range<Date>]
      def prev_period_range(period)
        case period
        when "quarter"
          (Date.current.beginning_of_quarter - 3.months)..(Date.current.beginning_of_quarter - 1.day)
        when "year"
          (Date.current.beginning_of_year - 1.year)..(Date.current.beginning_of_year - 1.day)
        else
          (Date.current.beginning_of_month - 1.month)..(Date.current.beginning_of_month - 1.day)
        end
      end

      # KPIカードデータを構築する
      #
      # @param invoices [ActiveRecord::Relation]
      # @param range [Range<Date>]
      # @return [Hash]
      def build_kpis(invoices, range)
        period = params[:period] || "month"
        prev_range = prev_period_range(period)

        current_revenue = invoices.where(issue_date: range).sum(:total_amount)
        prev_revenue = invoices.where(issue_date: prev_range).sum(:total_amount)

        outstanding = invoices.where(payment_status: %w[unpaid partial overdue]).sum(:remaining_amount)
        overdue_count = invoices.where(payment_status: "overdue").count

        current_collected = invoices.where(issue_date: range).sum(:paid_amount)
        current_issued = invoices.where(issue_date: range).sum(:total_amount)
        collection_rate = current_issued.positive? ? (current_collected.to_f / current_issued * 100).round(1) : 0.0

        prev_collected = invoices.where(issue_date: prev_range).sum(:paid_amount)
        prev_issued = invoices.where(issue_date: prev_range).sum(:total_amount)
        prev_rate = prev_issued.positive? ? (prev_collected.to_f / prev_issued * 100).round(1) : 0.0

        projects = current_tenant.projects.active
        project_counts = projects.where(status: Project::STATUSES).group(:status).count

        {
          revenue: { current: current_revenue, previous: prev_revenue },
          outstanding: { amount: outstanding, overdue_count: overdue_count },
          collection_rate: { current: collection_rate, previous: prev_rate },
          projects: project_counts
        }
      end

      # 遅延アラート情報を構築する
      #
      # @param invoices [ActiveRecord::Relation]
      # @return [Hash, nil]
      def build_alert(invoices)
        overdue = invoices.where(payment_status: "overdue")
        return nil unless overdue.exists?

        {
          overdue_count: overdue.count,
          overdue_amount: overdue.sum(:remaining_amount)
        }
      end

      # 売上推移を返す（過去6ヶ月）
      #
      # @param invoices [ActiveRecord::Relation]
      # @return [Array<Hash>]
      def revenue_trend(invoices)
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

      # 入金予定を返す（直近14日）
      #
      # @param invoices [ActiveRecord::Relation]
      # @return [Array<Hash>]
      def upcoming_payments(invoices)
        invoices.where(payment_status: %w[unpaid partial])
                .where(due_date: Date.current..(Date.current + 14))
                .order(:due_date)
                .limit(10)
                .map do |inv|
          {
            id: inv.uuid,
            document_number: inv.document_number,
            customer_name: inv.customer&.company_name,
            due_date: inv.due_date,
            remaining_amount: inv.remaining_amount
          }
        end
      end

      # 最近の取引一覧を返す
      #
      # @return [Array<Hash>]
      def recent_transactions
        current_tenant.documents.active
                      .includes(:customer)
                      .order(updated_at: :desc)
                      .limit(10)
                      .map do |doc|
          {
            id: doc.uuid,
            document_number: doc.document_number,
            document_type: doc.document_type,
            customer_name: doc.customer&.company_name,
            total_amount: doc.total_amount,
            status: doc.status,
            payment_status: doc.payment_status,
            updated_at: doc.updated_at
          }
        end
      end

      # 案件パイプラインサマリーを返す
      #
      # @return [Array<Hash>]
      def pipeline_summary
        current_tenant.projects.active
                      .where.not(status: "completed")
                      .group(:status)
                      .sum(:amount)
                      .map { |status, amount| { status: status, amount: amount } }
      end
    end
  end
end
