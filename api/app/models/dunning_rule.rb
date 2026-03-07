# frozen_string_literal: true

# 督促ルールモデル
#
# 支払い期限超過時の督促アクション（メール送信・社内アラート等）を定義する。
# エスカレーションルールとして他の督促ルールを参照できる。
#
# @example 督促ルールの作成
#   DunningRule.create!(
#     tenant: tenant,
#     name: "1回目督促メール",
#     trigger_days_after_due: 7,
#     action_type: "email",
#     send_to: "billing_contact",
#     subject_template: "【ご確認】請求書{{document_number}}のお支払いについて",
#     body_template: "{{company_name}}様\n\n請求書{{document_number}}のお支払い期限が過ぎております。",
#     is_active: true
#   )
class DunningRule < ApplicationRecord
  include TenantScoped

  belongs_to :tenant
  belongs_to :escalation_rule, class_name: "DunningRule", optional: true
  has_many :dunning_logs

  # アクション種別の一覧
  ACTION_TYPES = %w[email internal_alert both].freeze

  # 送信先種別の一覧
  SEND_TO_TYPES = %w[billing_contact primary_contact custom_email].freeze

  validates :name, presence: true
  validates :trigger_days_after_due, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :action_type, inclusion: { in: ACTION_TYPES }
  validates :send_to, inclusion: { in: SEND_TO_TYPES }

  # @!method self.active
  #   有効なルールのみを取得するスコープ
  #   @return [ActiveRecord::Relation] is_activeがtrueのレコード
  scope :active, -> { where(is_active: true) }

  # @!method self.ordered
  #   表示順で並べるスコープ
  #   @return [ActiveRecord::Relation] sort_order昇順のレコード
  scope :ordered, -> { order(:sort_order) }

  # 件名テンプレートに変数を展開する
  #
  # テンプレート内の{{key}}をvariablesハッシュの対応する値で置換する。
  #
  # @param variables [Hash{String => String}] テンプレート変数のキーと値のハッシュ
  # @return [String] 変数が展開された件名文字列
  def render_subject(variables)
    render_template(email_template_subject, variables)
  end

  # 本文テンプレートに変数を展開する
  #
  # テンプレート内の{{key}}をvariablesハッシュの対応する値で置換する。
  #
  # @param variables [Hash{String => String}] テンプレート変数のキーと値のハッシュ
  # @return [String] 変数が展開された本文文字列
  def render_body(variables)
    render_template(email_template_body, variables)
  end

  private

  # テンプレート文字列に変数を展開する
  #
  # {{key}}形式のプレースホルダーをvariablesハッシュの対応する値で置換する。
  #
  # @param template [String] テンプレート文字列
  # @param variables [Hash{String => String}] テンプレート変数のキーと値のハッシュ
  # @return [String] 変数が展開された文字列
  def render_template(template, variables)
    return "" if template.blank?

    result = template.dup
    variables.each do |key, value|
      result.gsub!("{{#{key}}}", value.to_s)
    end
    result
  end
end
