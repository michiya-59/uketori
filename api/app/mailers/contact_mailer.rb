# frozen_string_literal: true

# お問い合わせメーラー
#
# プランアップグレードや不具合報告などのお問い合わせメールを送信する。
class ContactMailer < ApplicationMailer
  # カテゴリの日本語ラベル
  CATEGORY_LABELS = {
    "bug" => "不具合報告",
    "feature_request" => "機能要望",
    "plan_inquiry" => "プラン変更",
    "billing" => "請求・お支払い",
    "account" => "アカウント",
    "data_issue" => "データに関する問題",
    "security" => "セキュリティ",
    "other" => "その他"
  }.freeze

  # 優先度の日本語ラベル
  PRIORITY_LABELS = {
    "low" => "低",
    "normal" => "通常",
    "high" => "高",
    "urgent" => "緊急"
  }.freeze

  # プランアップグレードお問い合わせメールを送信する
  #
  # @param tenant [Tenant] テナント
  # @param user [User] 問い合わせしたユーザー
  # @param desired_plan [String] 希望プラン
  # @param message [String] お問い合わせ内容
  # @return [Mail::Message]
  def plan_inquiry(tenant:, user:, desired_plan:, message:)
    @tenant = tenant
    @user = user
    @desired_plan = desired_plan
    @message = message

    mail(
      to: ENV.fetch("SUPPORT_EMAIL", "support@uketori.app"),
      subject: "【プラン変更お問い合わせ】#{tenant.name}"
    )
  end

  # 汎用お問い合わせメールを送信する
  #
  # @param tenant [Tenant] テナント
  # @param user [User] 問い合わせしたユーザー
  # @param category [String] カテゴリ
  # @param subject [String] 件名
  # @param body [String] お問い合わせ内容
  # @param priority [String] 優先度
  # @param page_url [String, nil] 問い合わせ元URL
  # @param user_agent [String, nil] ブラウザ情報
  # @return [Mail::Message]
  def general_inquiry(tenant:, user:, category:, subject:, body:, priority:, page_url: nil, user_agent: nil)
    @tenant = tenant
    @user = user
    @category = category
    @category_label = CATEGORY_LABELS[category] || category
    @subject = subject
    @body = body
    @priority = priority
    @priority_label = PRIORITY_LABELS[priority] || priority
    @page_url = page_url
    @user_agent = user_agent

    prefix = priority == "urgent" ? "【緊急】" : ""

    mail(
      to: ENV.fetch("SUPPORT_EMAIL", "support@uketori.app"),
      subject: "#{prefix}【#{@category_label}】#{subject} - #{tenant.name}"
    )
  end
end
