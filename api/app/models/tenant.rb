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

  validate :validate_allowed_ip_addresses

  # ActiveStorage添付を既存のURLカラム互換で返す
  #
  # @return [String, nil]
  def logo_storage_url
    attachment_storage_url(logo, logo_url)
  end

  # ActiveStorage添付を既存のURLカラム互換で返す
  #
  # @return [String, nil]
  def seal_storage_url
    attachment_storage_url(seal, seal_url)
  end

  # 指定されたIPアドレスが許可リストに含まれるか判定する
  #
  # IP制限が無効の場合は常にtrueを返す。
  # 許可リストにはCIDR表記（例: 192.168.1.0/24）も使用可能。
  #
  # @param ip [String] 検証するIPアドレス
  # @return [Boolean] 許可されている場合true
  def ip_allowed?(ip)
    return true unless ip_restriction_enabled?
    return true if allowed_ip_addresses.blank?

    client_ip = IPAddr.new(ip)
    allowed_ip_addresses.any? do |allowed|
      IPAddr.new(allowed).include?(client_ip)
    end
  rescue IPAddr::InvalidAddressError
    false
  end

  private

  # 許可IPアドレスのフォーマットを検証する
  #
  # @return [void]
  def validate_allowed_ip_addresses
    return if allowed_ip_addresses.blank?

    allowed_ip_addresses.each do |ip|
      IPAddr.new(ip)
    rescue IPAddr::InvalidAddressError
      errors.add(:allowed_ip_addresses, "に無効なIPアドレスが含まれています: #{ip}")
    end
  end

  # 適格番号が変更された場合に検証ジョブをキューに追加する
  #
  # @return [void]
  def enqueue_invoice_number_verification
    return if invoice_registration_number.blank?

    InvoiceNumberVerificationJob.perform_later("Tenant", id)
  end

  # @param attachment [ActiveStorage::Attached::One]
  # @param fallback [String, nil]
  # @return [String, nil]
  def attachment_storage_url(attachment, fallback)
    return "blob://#{attachment.blob.key}" if attachment.attached?

    fallback
  end
end
