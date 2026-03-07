# frozen_string_literal: true

require "net/http"
require "json"

# AI帳票明細提案サービス
#
# 同一顧客の過去帳票と品目マスタを参照し、Claude Haiku APIを使用して
# 見積・請求の明細行を自動提案する。
#
# @example
#   result = AiDocumentSuggester.call(document)
#   result[:items]      # => [{ name: "Web制作", quantity: 1, unit: "式", unit_price: 500000, reason: "過去実績" }]
#   result[:confidence] # => 0.85
class AiDocumentSuggester
  class << self
    # 帳票に対するAI明細提案を取得する
    #
    # @param document [Document] 対象の帳票
    # @return [Hash] { items: Array<Hash>, confidence: Float }
    def call(document)
      new(document).suggest
    end
  end

  # @param document [Document] 対象の帳票
  def initialize(document)
    @document = document
    @tenant = document.tenant
    @customer = document.customer
  end

  # AI明細提案を実行する
  #
  # @return [Hash] { items: Array<Hash>, confidence: Float }
  def suggest
    past_docs = fetch_past_documents
    products = fetch_products

    prompt = build_prompt(past_docs, products)
    response = call_claude_api(prompt)

    return fallback_response if response.nil?

    parse_response(response)
  rescue StandardError => e
    Rails.logger.warn("AiDocumentSuggester error: #{e.message}")
    fallback_response
  end

  private

  # 同一顧客の過去帳票を取得する（最大5件）
  #
  # @return [Array<Document>]
  def fetch_past_documents
    @tenant.documents
           .where(customer: @customer)
           .where.not(id: @document.id)
           .active
           .includes(:document_items)
           .order(created_at: :desc)
           .limit(5)
  end

  # テナントの品目マスタを取得する（最大50件）
  #
  # @return [Array<Product>]
  def fetch_products
    @tenant.products
           .where(is_active: true)
           .order(:name)
           .limit(50)
  end

  # AIプロンプトを構築する
  #
  # @param past_docs [Array<Document>] 過去の帳票
  # @param products [Array<Product>] 品目マスタ
  # @return [String]
  def build_prompt(past_docs, products)
    past_items_text = past_docs.flat_map do |doc|
      doc.document_items.map do |item|
        "- #{item.name}: 数量#{item.quantity} #{item.unit}, 単価¥#{item.unit_price}"
      end
    end.join("\n")

    products_text = products.map do |p|
      "- #{p.name}: 単価¥#{p.unit_price} (#{p.unit})"
    end.join("\n")

    <<~PROMPT
      あなたは日本の中小企業向け見積・請求システムのAIアシスタントです。
      以下の情報を参考に、この顧客への帳票の明細行を提案してください。

      ## 顧客情報
      顧客名: #{@customer.company_name}
      帳票種別: #{@document.document_type}

      ## 過去の取引明細（同一顧客）
      #{past_items_text.presence || "（過去の取引なし）"}

      ## 利用可能な品目マスタ
      #{products_text.presence || "（品目未登録）"}

      ## 出力形式
      以下のJSON形式で3〜5件の明細を提案してください。
      ```json
      {
        "items": [
          {
            "name": "品名",
            "quantity": 1,
            "unit": "式",
            "unit_price": 100000,
            "reason": "提案理由"
          }
        ],
        "confidence": 0.85
      }
      ```

      過去の取引や品目マスタに基づく提案を優先してください。
      confidenceは0.0〜1.0で、過去データがある場合は高く、ない場合は低く設定してください。
    PROMPT
  end

  # Claude Haiku APIを呼び出す
  #
  # @param prompt [String] プロンプト
  # @return [String, nil] AIレスポンスのテキスト
  def call_claude_api(prompt)
    api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)
    return nil if api_key.blank?

    response = Net::HTTP.post(
      URI("https://api.anthropic.com/v1/messages"),
      {
        model: "claude-haiku-4-5-20251001",
        max_tokens: 1024,
        messages: [{ role: "user", content: prompt }]
      }.to_json,
      {
        "Content-Type" => "application/json",
        "x-api-key" => api_key,
        "anthropic-version" => "2023-06-01"
      }
    )

    return nil unless response.is_a?(Net::HTTPSuccess)

    body = JSON.parse(response.body)
    body.dig("content", 0, "text")
  rescue StandardError => e
    Rails.logger.warn("Claude API error: #{e.message}")
    nil
  end

  # AIレスポンスをパースする
  #
  # @param response_text [String] AIレスポンステキスト
  # @return [Hash] { items: Array<Hash>, confidence: Float }
  def parse_response(response_text)
    json_match = response_text.match(/\{[\s\S]*"items"[\s\S]*\}/m)
    return fallback_response unless json_match

    result = JSON.parse(json_match[0])
    items = (result["items"] || []).map do |item|
      {
        name: item["name"].to_s,
        quantity: item["quantity"].to_f,
        unit: item["unit"].to_s,
        unit_price: item["unit_price"].to_f,
        reason: item["reason"].to_s
      }
    end

    {
      items: items,
      confidence: (result["confidence"] || 0.5).to_f.clamp(0.0, 1.0)
    }
  rescue JSON::ParserError
    fallback_response
  end

  # フォールバックレスポンスを返す
  #
  # @return [Hash]
  def fallback_response
    { items: [], confidence: 0.0 }
  end
end
