# frozen_string_literal: true

# 請求書期限超過チェックジョブ
#
# 毎日9:00に実行され、以下を行う:
# - 期限超過の請求書のpayment_statusをoverdueに更新し、invoice_overdue通知を生成
# - 支払期日3日前の請求書に対してinvoice_due_soon通知を生成
# - 高額未回収（100万円以上）の超過請求書にlarge_overdue_alert通知を生成
#
# @example SolidQueue recurring schedule
#   invoice_overdue_check:
#     class: InvoiceOverdueCheckJob
#     schedule: "0 9 * * *"
class InvoiceOverdueCheckJob < ApplicationJob
  queue_as :default

  LARGE_OVERDUE_THRESHOLD = 1_000_000

  # @return [void]
  def perform
    mark_overdue_invoices
    notify_due_soon_invoices
    notify_large_overdue_invoices
  end

  private

  # 期限超過の請求書をoverdue化し通知を生成する
  #
  # @return [void]
  def mark_overdue_invoices
    overdue_docs = Document.where(document_type: "invoice")
                           .where(payment_status: "unpaid")
                           .where("due_date < ?", Date.current)
                           .includes(:tenant, :customer)

    overdue_docs.find_each do |doc|
      doc.update!(payment_status: "overdue")
      notify_roles(doc.tenant, %w[owner accountant], "invoice_overdue",
                   "請求書 #{doc.document_number} が支払期限を超過しています",
                   "#{doc.customer&.company_name}宛 #{doc.document_number} の支払期限（#{doc.due_date}）を超過しています。")
    rescue StandardError => e
      Rails.logger.error("InvoiceOverdueCheckJob overdue failed for doc #{doc.id}: #{e.message}")
    end
  end

  # 支払期日3日前の請求書に対してdue_soon通知を生成する
  #
  # @return [void]
  def notify_due_soon_invoices
    due_soon_date = Date.current + 3.days
    docs = Document.where(document_type: "invoice")
                   .where(payment_status: "unpaid")
                   .where(due_date: due_soon_date)
                   .includes(:tenant, :customer)

    docs.find_each do |doc|
      notify_roles(doc.tenant, %w[owner accountant], "invoice_due_soon",
                   "請求書 #{doc.document_number} の支払期日が近づいています",
                   "#{doc.customer&.company_name}宛 #{doc.document_number} の支払期日は#{doc.due_date}です。")
    rescue StandardError => e
      Rails.logger.error("InvoiceOverdueCheckJob due_soon failed for doc #{doc.id}: #{e.message}")
    end
  end

  # 高額未回収の超過請求書にアラート通知を生成する
  #
  # @return [void]
  def notify_large_overdue_invoices
    docs = Document.where(document_type: "invoice")
                   .where(payment_status: %w[overdue partial])
                   .where("remaining_amount >= ?", LARGE_OVERDUE_THRESHOLD)
                   .includes(:tenant, :customer)

    docs.find_each do |doc|
      notify_roles(doc.tenant, %w[owner], "large_overdue_alert",
                   "高額未回収アラート: #{doc.document_number}",
                   "#{doc.customer&.company_name}宛 #{doc.document_number} の未回収額が#{doc.remaining_amount&.to_i&.to_s(:delimited) || 0}円です。")
    rescue StandardError => e
      Rails.logger.error("InvoiceOverdueCheckJob large_overdue failed for doc #{doc.id}: #{e.message}")
    end
  end

  # 指定ロールのユーザーに通知を送信する
  #
  # @param tenant [Tenant] テナント
  # @param roles [Array<String>] 通知対象ロール
  # @param notification_type [String] 通知タイプ
  # @param title [String] 通知タイトル
  # @param body [String] 通知本文
  # @return [void]
  def notify_roles(tenant, roles, notification_type, title, body)
    tenant.users.where(role: roles).find_each do |user|
      Notification.create!(
        tenant: tenant,
        user: user,
        notification_type: notification_type,
        title: title,
        body: body
      )
    end
  end
end
