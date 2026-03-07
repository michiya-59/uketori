# frozen_string_literal: true

# テナントモデル
#
# マルチテナントアーキテクチャの中核となるモデル。
# 各テナント（組織）の情報と設定を管理する。
#
# @example テナントの作成
#   Tenant.create!(
#     name: "株式会社サンプル",
#     uuid: SecureRandom.uuid,
#     plan: "standard",
#     industry_type: "manufacturing",
#     default_tax_rate: 10.0,
#     fiscal_year_start_month: 4,
#     default_payment_terms_days: 30
#   )
class Tenant < ApplicationRecord
  include UuidFindable
  include SoftDeletable

  has_one_attached :logo
  has_one_attached :seal

  has_many :users, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :payment_records, dependent: :destroy
  has_many :bank_statements, dependent: :destroy
  has_many :dunning_rules, dependent: :destroy
  has_many :dunning_logs, dependent: :destroy
  has_many :import_jobs, dependent: :destroy
  has_many :recurring_rules, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :audit_logs, dependent: :destroy
  has_many :credit_score_histories, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
  validates :uuid, uniqueness: true, allow_nil: true
  validates :plan, inclusion: { in: %w[free starter standard professional] }
  validates :industry_type, presence: true
  validates :default_tax_rate, numericality: { greater_than_or_equal_to: 0 }
  validates :fiscal_year_start_month, inclusion: { in: 1..12 }
  validates :default_payment_terms_days, numericality: { greater_than: 0 }

  enum :bank_account_type, { ordinary: 0, checking: 1 }, prefix: true

  after_commit :enqueue_invoice_number_verification, if: :invoice_registration_number_previously_changed?

  private

  # 適格番号が変更された場合に検証ジョブをキューに追加する
  #
  # @return [void]
  def enqueue_invoice_number_verification
    return if invoice_registration_number.blank?

    InvoiceNumberVerificationJob.perform_later("Tenant", id)
  end
end
