# frozen_string_literal: true

# 帳票番号を自動生成するサービス
#
# テナントの採番フォーマット設定に基づいて、帳票タイプごとに
# ユニークな連番を生成する。
#
# @example
#   DocumentNumberGenerator.call(tenant, "invoice")
#   #=> "INV-202602-0001"
class DocumentNumberGenerator
  # 帳票タイプ別のプレフィックス
  TYPE_PREFIXES = {
    "estimate" => "EST",
    "purchase_order" => "PO",
    "order_confirmation" => "OC",
    "delivery_note" => "DN",
    "invoice" => "INV",
    "receipt" => "RCP"
  }.freeze

  class << self
    # 次の帳票番号を生成する
    #
    # @param tenant [Tenant] 対象テナント
    # @param document_type [String] 帳票タイプ
    # @param issue_date [Date] 発行日（デフォルト: 今日）
    # @return [String] 生成された帳票番号
    def call(tenant, document_type, issue_date: Date.current)
      new(tenant, document_type, issue_date).generate
    end
  end

  # @param tenant [Tenant]
  # @param document_type [String]
  # @param issue_date [Date]
  def initialize(tenant, document_type, issue_date)
    @tenant = tenant
    @document_type = document_type
    @issue_date = issue_date
  end

  # 帳票番号を生成する
  #
  # @return [String] ユニークな帳票番号
  def generate
    format_string = @tenant.document_sequence_format || "{prefix}-{YYYY}{MM}-{SEQ}"
    seq = next_sequence_number

    format_string
      .gsub("{prefix}", prefix)
      .gsub("{YYYY}", @issue_date.year.to_s)
      .gsub("{YY}", @issue_date.strftime("%y"))
      .gsub("{MM}", @issue_date.strftime("%m"))
      .gsub("{DD}", @issue_date.strftime("%d"))
      .gsub("{SEQ}", seq.to_s.rjust(4, "0"))
  end

  private

  # @return [String] 帳票タイプのプレフィックス
  def prefix
    TYPE_PREFIXES[@document_type] || @document_type.upcase[0..2]
  end

  # @return [Integer] 次のシーケンス番号
  def next_sequence_number
    last_doc = @tenant.documents
                      .where(document_type: @document_type, deleted_at: nil)
                      .order(id: :desc)
                      .first

    return 1 unless last_doc

    # 既存番号からシーケンス部分を抽出
    last_number = last_doc.document_number
    seq_match = last_number.match(/(\d{4,})$/)
    return 1 unless seq_match

    seq_match[1].to_i + 1
  end
end
