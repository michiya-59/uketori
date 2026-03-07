# frozen_string_literal: true

# 帳票を別タイプに変換するサービス
#
# 見積書→請求書、発注書→納品書等の帳票変換ロジックを提供する。
# 変換元の明細行をコピーし、新しい帳票番号を採番して
# 新規帳票として保存する。
#
# @example
#   result = DocumentConverter.call(estimate, "invoice", user: current_user, tenant: tenant)
#   result.document_type # => "invoice"
class DocumentConverter
  # 許可された変換ルール
  CONVERSIONS = {
    "estimate" => %w[invoice purchase_order],
    "purchase_order" => %w[delivery_note invoice],
    "invoice" => %w[receipt]
  }.freeze

  # 変換エラー
  class ConversionError < StandardError; end

  class << self
    # 帳票を変換する
    #
    # @param source [Document] 変換元の帳票
    # @param target_type [String] 変換先の帳票種別
    # @param user [User] 実行ユーザー
    # @param tenant [Tenant] テナント
    # @return [Document] 変換後の帳票
    # @raise [ConversionError] 不正な変換の場合
    def call(source, target_type, user:, tenant:)
      new(source, target_type, user: user, tenant: tenant).convert!
    end
  end

  # @param source [Document] 変換元
  # @param target_type [String] 変換先タイプ
  # @param user [User] 実行ユーザー
  # @param tenant [Tenant] テナント
  def initialize(source, target_type, user:, tenant:)
    @source = source
    @target_type = target_type
    @user = user
    @tenant = tenant
  end

  # 帳票変換を実行する
  #
  # @return [Document] 変換された帳票
  # @raise [ConversionError] 不正な変換の場合
  def convert!
    validate_conversion!

    ActiveRecord::Base.transaction do
      converted = build_converted_document
      converted.save!
      copy_items!(converted)
      DocumentCalculator.call(converted)
      create_version!(converted)
      converted
    end
  end

  private

  # 変換が許可されているかバリデーションする
  #
  # @return [void]
  # @raise [ConversionError]
  def validate_conversion!
    allowed = CONVERSIONS[@source.document_type] || []
    return if allowed.include?(@target_type)

    raise ConversionError, "#{@source.document_type}から#{@target_type}への変換はできません"
  end

  # 変換先の帳票を構築する
  #
  # @return [Document]
  def build_converted_document
    converted = @source.dup
    converted.uuid = nil
    converted.document_type = @target_type
    converted.status = "draft"
    converted.document_number = DocumentNumberGenerator.call(@tenant, @target_type)
    converted.parent_document_id = @source.id
    converted.payment_status = "unpaid" if @target_type == "invoice"
    converted.sent_at = nil
    converted.locked_at = nil
    converted.pdf_url = nil
    converted.pdf_generated_at = nil
    converted.created_by_user = @user
    converted
  end

  # 明細行をコピーする
  #
  # @param target [Document] コピー先帳票
  # @return [void]
  def copy_items!(target)
    @source.document_items.each do |item|
      new_item = item.dup
      new_item.document = target
      new_item.save!
    end
  end

  # バージョンスナップショットを作成する
  #
  # @param document [Document]
  # @return [DocumentVersion]
  def create_version!(document)
    document.document_versions.create!(
      version: 1,
      snapshot: document.attributes.except("id").merge(
        items: document.document_items.map(&:attributes)
      ),
      changed_by_user: @user,
      change_reason: "#{@source.document_type}からの変換"
    )
  end
end
