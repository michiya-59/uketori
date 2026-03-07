# frozen_string_literal: true

# 督促実行サービス
#
# 期限超過の請求書を検出し、該当する督促ルールに基づいて
# メール送信やアラート生成を行い、dunning_logsに記録する。
#
# @example
#   result = DunningExecutor.call(tenant)
#   result[:sent]    # => 5
#   result[:skipped] # => 2
class DunningExecutor
  class << self
    # テナントの督促を実行する
    #
    # @param tenant [Tenant] テナント
    # @return [Hash] { sent: Integer, skipped: Integer, failed: Integer }
    def call(tenant)
      new(tenant).execute!
    end
  end

  # @param tenant [Tenant]
  def initialize(tenant)
    @tenant = tenant
  end

  # 督促を実行する
  #
  # @return [Hash] 実行結果
  def execute!
    rules = @tenant.dunning_rules.active.ordered
    return { sent: 0, skipped: 0, failed: 0 } if rules.empty?

    overdue_docs = @tenant.documents.active
                          .where(document_type: "invoice")
                          .where(payment_status: %w[overdue partial])
                          .where("due_date < ?", Date.current)
                          .includes(:customer)

    results = { sent: 0, skipped: 0, failed: 0 }

    overdue_docs.find_each do |doc|
      overdue_days = (Date.current - doc.due_date).to_i
      applicable_rule = find_applicable_rule(rules, doc, overdue_days)

      if applicable_rule.nil?
        results[:skipped] += 1
        next
      end

      success = execute_rule!(applicable_rule, doc, overdue_days)
      if success
        results[:sent] += 1
      else
        results[:failed] += 1
      end
    end

    results
  end

  private

  # 適用可能なルールを見つける
  #
  # @param rules [Array<DunningRule>] ルール一覧
  # @param doc [Document] 対象帳票
  # @param overdue_days [Integer] 超過日数
  # @return [DunningRule, nil]
  def find_applicable_rule(rules, doc, overdue_days)
    applicable = rules.select { |r| overdue_days >= r.trigger_days_after_due }
    return nil if applicable.empty?

    # 最も厳しい（trigger_days_after_dueが大きい）ルールを適用
    rule = applicable.max_by(&:trigger_days_after_due)

    # max_dunning_countチェック
    sent_count = doc.dunning_logs.where(dunning_rule: rule).count
    return nil if sent_count >= rule.max_dunning_count

    # interval_daysチェック（前回送信からの経過日数）
    last_log = doc.dunning_logs.where(dunning_rule: rule).order(created_at: :desc).first
    if last_log.present?
      days_since_last = (Date.current - last_log.created_at.to_date).to_i
      return nil if days_since_last < rule.interval_days
    end

    rule
  end

  # ルールを実行する
  #
  # @param rule [DunningRule]
  # @param doc [Document]
  # @param overdue_days [Integer]
  # @return [Boolean]
  def execute_rule!(rule, doc, overdue_days)
    variables = build_variables(doc, overdue_days)
    subject = rule.render_subject(variables)
    body = rule.render_body(variables)
    recipient = resolve_recipient(rule, doc.customer)

    log = DunningLog.create!(
      tenant: @tenant,
      document: doc,
      dunning_rule: rule,
      customer: doc.customer,
      action_type: rule.action_type,
      sent_to_email: recipient,
      email_subject: subject,
      email_body: body,
      status: "sent",
      overdue_days: overdue_days,
      remaining_amount: doc.remaining_amount || 0
    )

    # メール送信
    if %w[email both].include?(rule.action_type)
      DunningMailer.send_dunning(log).deliver_later
    end

    # 帳票の督促情報を更新
    doc.update!(
      last_dunning_at: Time.current,
      dunning_count: doc.dunning_count + 1
    )

    # 督促送信通知
    notify_roles(@tenant, %w[owner accountant], "dunning_sent",
                 "督促メールを送信しました",
                 "#{doc.customer&.company_name}宛 #{doc.document_number} への督促メール（#{overdue_days}日超過）を送信しました。")

    true
  rescue StandardError => e
    Rails.logger.error("Dunning execution failed for doc #{doc.id}: #{e.message}")

    # 督促失敗通知
    notify_roles(@tenant, %w[owner admin], "dunning_failed",
                 "督促メール送信に失敗しました",
                 "#{doc.customer&.company_name}宛 #{doc.document_number} への督促メール送信に失敗しました: #{e.message}")

    false
  end

  # テンプレート変数を構築する
  #
  # @param doc [Document]
  # @param overdue_days [Integer]
  # @return [Hash{String => String}]
  def build_variables(doc, overdue_days)
    {
      "customer_name" => doc.customer&.company_name || "",
      "document_number" => doc.document_number,
      "total_amount" => format_amount(doc.total_amount),
      "remaining_amount" => format_amount(doc.remaining_amount),
      "due_date" => doc.due_date&.strftime("%Y年%m月%d日") || "",
      "overdue_days" => overdue_days.to_s,
      "company_name" => @tenant.name,
      "bank_info" => build_bank_info
    }
  end

  # 送信先メールアドレスを解決する
  #
  # @param rule [DunningRule]
  # @param customer [Customer]
  # @return [String]
  def resolve_recipient(rule, customer)
    case rule.send_to
    when "billing_contact"
      billing = customer.customer_contacts&.find_by(is_billing_contact: true)
      billing&.email || customer.email || ""
    when "primary_contact"
      primary = customer.customer_contacts&.find_by(is_primary: true)
      primary&.email || customer.email || ""
    when "custom_email"
      rule.custom_email || ""
    else
      customer.email || ""
    end
  end

  # 振込先情報を構築する
  #
  # @return [String]
  def build_bank_info
    parts = []
    parts << @tenant.bank_name if @tenant.bank_name.present?
    parts << @tenant.bank_branch_name if @tenant.bank_branch_name.present?
    parts << "#{@tenant.bank_account_type} #{@tenant.bank_account_number}" if @tenant.bank_account_number.present?
    parts << @tenant.bank_account_holder if @tenant.bank_account_holder.present?
    parts.join(" / ")
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
    tenant.users.active.where(role: roles).find_each do |user|
      Notification.create!(
        tenant: tenant,
        user: user,
        notification_type: notification_type,
        title: title,
        body: body
      )
    end
  end

  # 金額をフォーマットする
  #
  # @param amount [Integer, nil]
  # @return [String]
  def format_amount(amount)
    return "0" if amount.nil?

    "¥#{amount.to_s.gsub(/(\\d)(?=(\\d{3})+(?!\\d))/, '\\1,')}"
  end
end
