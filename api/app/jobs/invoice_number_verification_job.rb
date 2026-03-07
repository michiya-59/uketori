# frozen_string_literal: true

# 適格請求書発行事業者番号の検証を非同期で実行するジョブ
#
# テナントまたは顧客の適格番号を国税庁APIで検証し、
# 結果をDBに反映する。SolidQueueで非同期実行される。
#
# @example テナントの番号を検証
#   InvoiceNumberVerificationJob.perform_later("Tenant", tenant.id)
#
# @example 顧客の番号を検証
#   InvoiceNumberVerificationJob.perform_later("Customer", customer.id)
class InvoiceNumberVerificationJob < ApplicationJob
  queue_as :default

  # 検証対象のモデルタイプ
  VERIFIABLE_TYPES = %w[Tenant Customer].freeze

  # 適格番号を検証してDBに反映する
  #
  # @param record_type [String] モデルクラス名（"Tenant" or "Customer"）
  # @param record_id [Integer] レコードID
  # @return [void]
  # @raise [ArgumentError] 不正なrecord_typeの場合
  def perform(record_type, record_id)
    unless VERIFIABLE_TYPES.include?(record_type)
      raise ArgumentError, "Invalid record type: #{record_type}"
    end

    record = record_type.constantize.find_by(id: record_id)
    return if record.nil?

    number = record.invoice_registration_number
    return if number.blank?

    result = InvoiceNumberVerifier.verify(number)

    record.update!(
      invoice_number_verified: result[:valid],
      invoice_number_verified_at: Time.current
    )

    Rails.logger.info(
      "InvoiceNumberVerification: #{record_type}##{record_id} " \
      "number=#{number} valid=#{result[:valid]} " \
      "#{result[:error] ? "error=#{result[:error]}" : "name=#{result[:name]}"}"
    )
  end
end
