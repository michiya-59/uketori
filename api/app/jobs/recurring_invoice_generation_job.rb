# frozen_string_literal: true

# 定期請求書生成ジョブ
#
# 毎日6:00に実行され、next_generation_dateが到来した定期請求ルールに基づき
# 請求書を自動生成し、通知を作成する。
#
# @example SolidQueue recurring schedule
#   recurring_invoice_generation:
#     class: RecurringInvoiceGenerationJob
#     schedule: every day at 6am Asia/Tokyo
class RecurringInvoiceGenerationJob < ApplicationJob
  queue_as :default

  # @return [void]
  def perform
    generated = 0

    RecurringRule.due_for_generation.includes(:tenant, :customer).find_each do |rule|
      generate_invoice(rule)
      advance_next_date(rule)
      generated += 1
    rescue StandardError => e
      Rails.logger.error("RecurringInvoiceGenerationJob failed for rule #{rule.id}: #{e.message}")
    end

    Rails.logger.info("RecurringInvoiceGenerationJob: #{generated} invoices generated")
  end

  private

  # 定期ルールに基づいて請求書を生成する
  #
  # @param rule [RecurringRule]
  # @return [Document]
  def generate_invoice(rule)
    tenant = rule.tenant
    issue_date = Date.new(Date.current.year, Date.current.month, [rule.issue_day, Date.current.end_of_month.day].min)
    doc_number = DocumentNumberGenerator.call(tenant, "invoice", issue_date: issue_date)

    doc = Document.create!(
      tenant: tenant,
      customer: rule.customer,
      project: rule.project,
      created_by_user: tenant.users.where(role: "owner").first,
      document_type: "invoice",
      document_number: doc_number,
      status: "draft",
      issue_date: issue_date,
      due_date: issue_date + (tenant.default_payment_terms_days || 30).days,
      payment_status: "unpaid",
      title: rule.name
    )

    # テンプレートアイテムをコピー（rule.template_dataがある場合）
    if rule.template_data.present?
      items = rule.template_data.is_a?(String) ? JSON.parse(rule.template_data) : rule.template_data
      items.each_with_index do |item, i|
        doc.document_items.create!(
          name: item["name"],
          quantity: item["quantity"] || 1,
          unit: item["unit"] || "式",
          unit_price: item["unit_price"] || 0,
          tax_rate: item["tax_rate"] || tenant.default_tax_rate,
          tax_rate_type: item["tax_rate_type"] || "standard",
          sort_order: i + 1
        )
      end
      DocumentCalculator.call(doc)
    end

    # 通知作成
    tenant.users.where(role: %w[owner accountant]).find_each do |user|
      Notification.create!(
        tenant: tenant,
        user: user,
        notification_type: "recurring_generated",
        title: "定期請求書が生成されました",
        body: "#{rule.customer.company_name}宛の定期請求書 #{doc_number} を生成しました。"
      )
    end

    doc
  end

  # 次回生成日を更新する
  #
  # @param rule [RecurringRule]
  # @return [void]
  def advance_next_date(rule)
    next_date = case rule.frequency
                when "monthly"
                  rule.next_generation_date + 1.month
                when "quarterly"
                  rule.next_generation_date + 3.months
                when "yearly"
                  rule.next_generation_date + 1.year
                else
                  rule.next_generation_date + 1.month
                end
    rule.update!(next_generation_date: next_date)
  end
end
