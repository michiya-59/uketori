# frozen_string_literal: true

# AI自動カラムマッピングサービス
#
# インポートファイルのヘッダーを分析し、システム内部のテーブル・カラムへの
# マッピングを自動提案する。既知フォーマットはパターンマッチング、
# 不明フォーマットはClaude Haiku APIで推論する。
#
# @example
#   result = AiColumnMapper.call(headers, "board")
#   result[:mappings]            # => [{source:, target_table:, target_column:, confidence:}, ...]
#   result[:overall_confidence]  # => 0.92
class AiColumnMapper
  # 既知フォーマットのマッピング定義
  KNOWN_PATTERNS = {
    "board" => {
      "会社名" => { table: "customers", column: "company_name" },
      "取引先名" => { table: "customers", column: "company_name" },
      "取引先コード" => { table: "customers", column: "customer_code" },
      "担当者" => { table: "customer_contacts", column: "name" },
      "担当者名" => { table: "customer_contacts", column: "name" },
      "メールアドレス" => { table: "customer_contacts", column: "email" },
      "電話番号" => { table: "customers", column: "phone" },
      "住所" => { table: "customers", column: "address_line1" },
      "郵便番号" => { table: "customers", column: "postal_code" },
      "見積番号" => { table: "documents", column: "document_number" },
      "請求番号" => { table: "documents", column: "document_number" },
      "件名" => { table: "documents", column: "subject" },
      "発行日" => { table: "documents", column: "issue_date" },
      "期限日" => { table: "documents", column: "due_date" },
      "合計金額" => { table: "documents", column: "total_amount" },
      "税込金額" => { table: "documents", column: "total_amount" },
      "品名" => { table: "document_items", column: "name" },
      "品目名" => { table: "document_items", column: "name" },
      "単価" => { table: "document_items", column: "unit_price" },
      "数量" => { table: "document_items", column: "quantity" },
      "金額" => { table: "document_items", column: "amount" },
      "備考" => { table: "documents", column: "notes" }
    }
  }.freeze

  # ウケトリの対象テーブル・カラム一覧（AIプロンプト用）
  TARGET_SCHEMA = {
    "customers" => %w[company_name company_name_kana customer_code customer_type postal_code
                      address_line1 address_line2 phone fax email website notes],
    "customer_contacts" => %w[name email phone department position is_primary is_billing],
    "documents" => %w[document_number document_type subject issue_date due_date
                      total_amount notes payment_terms],
    "document_items" => %w[name description quantity unit unit_price tax_rate amount],
    "products" => %w[name code description unit unit_price tax_rate is_active],
    "projects" => %w[name code description status start_date end_date]
  }.freeze

  class << self
    # ヘッダーからカラムマッピングを生成する
    #
    # @param headers [Array<String>] CSVヘッダー
    # @param source_type [String] インポート元 ("board", "excel", "csv_generic")
    # @return [Hash] { mappings: Array<Hash>, overall_confidence: Float }
    def call(headers, source_type)
      new(headers, source_type).map!
    end
  end

  # @param headers [Array<String>]
  # @param source_type [String]
  def initialize(headers, source_type)
    @headers = headers.map(&:strip)
    @source_type = source_type
  end

  # マッピングを生成する
  #
  # @return [Hash]
  def map!
    # Step 1: DBに登録された既知定義でマッチ
    mappings = try_database_definitions

    # Step 2: ハードコード済みパターンでマッチ（未マッチ分のみ）
    mappings = try_known_patterns(mappings) if has_unmatched?(mappings)

    # Step 3: 残りはAI推論
    mappings = try_ai_mapping(mappings) if has_unmatched?(mappings)

    confidences = mappings.map { |m| m[:confidence] }
    overall = confidences.any? ? (confidences.sum / confidences.size).round(2) : 0.0

    { mappings: mappings, overall_confidence: overall }
  end

  private

  # DB定義でマッピングを試みる
  #
  # @return [Array<Hash>]
  def try_database_definitions
    definitions = ImportColumnDefinition.for_source(@source_type).index_by(&:source_column_name)

    @headers.map do |header|
      defn = definitions[header]
      if defn
        { source: header, target_table: defn.target_table, target_column: defn.target_column,
          confidence: 1.0, method: "database" }
      else
        { source: header, target_table: nil, target_column: nil, confidence: 0.0, method: nil }
      end
    end
  end

  # 既知パターンでマッピングを試みる
  #
  # @param mappings [Array<Hash>]
  # @return [Array<Hash>]
  def try_known_patterns(mappings)
    pattern = KNOWN_PATTERNS[@source_type] || KNOWN_PATTERNS.values.reduce({}, :merge)

    mappings.map do |m|
      next m if m[:confidence] > 0

      match = pattern[m[:source]]
      if match
        m.merge(target_table: match[:table], target_column: match[:column],
                confidence: 0.95, method: "pattern")
      else
        # 部分一致を試みる
        partial = pattern.find { |key, _| m[:source].include?(key) || key.include?(m[:source]) }
        if partial
          m.merge(target_table: partial[1][:table], target_column: partial[1][:column],
                  confidence: 0.70, method: "partial_pattern")
        else
          m
        end
      end
    end
  end

  # Claude Haiku APIでマッピングを推論する
  #
  # @param mappings [Array<Hash>]
  # @return [Array<Hash>]
  def try_ai_mapping(mappings)
    unmatched_headers = mappings.select { |m| m[:confidence] == 0.0 }.map { |m| m[:source] }
    return mappings if unmatched_headers.empty?

    ai_results = call_claude_api(unmatched_headers)
    return mappings unless ai_results

    mappings.map do |m|
      next m if m[:confidence] > 0

      ai_match = ai_results.find { |r| r["source"] == m[:source] }
      if ai_match && ai_match["target_table"].present?
        m.merge(
          target_table: ai_match["target_table"],
          target_column: ai_match["target_column"],
          confidence: (ai_match["confidence"] || 0.6).to_f.round(2),
          method: "ai"
        )
      else
        m.merge(confidence: 0.0, method: "unmatched")
      end
    end
  end

  # 未マッチのヘッダーが存在するか
  #
  # @param mappings [Array<Hash>]
  # @return [Boolean]
  def has_unmatched?(mappings)
    mappings.any? { |m| m[:confidence] == 0.0 }
  end

  # Claude APIを呼び出してマッピング推論する
  #
  # @param headers [Array<String>]
  # @return [Array<Hash>, nil]
  def call_claude_api(headers)
    api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)
    return nil if api_key.blank?

    prompt = build_ai_prompt(headers)

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
    text = body.dig("content", 0, "text")
    return nil if text.blank?

    json_match = text.match(/\[.*\]/m)
    return nil unless json_match

    JSON.parse(json_match[0])
  rescue StandardError => e
    Rails.logger.warn("AiColumnMapper AI call failed: #{e.message}")
    nil
  end

  # AIプロンプトを構築する
  #
  # @param headers [Array<String>]
  # @return [String]
  def build_ai_prompt(headers)
    schema_text = TARGET_SCHEMA.map do |table, columns|
      "#{table}: #{columns.join(', ')}"
    end.join("\n")

    <<~PROMPT
      あなたはデータ移行のエキスパートです。以下のCSVヘッダーを分析し、
      適切なデータベーステーブルとカラムにマッピングしてください。

      ## CSVヘッダー
      #{headers.join(', ')}

      ## 対象テーブル・カラム
      #{schema_text}

      ## 出力形式（JSON配列）
      [{"source": "CSVヘッダー名", "target_table": "テーブル名", "target_column": "カラム名", "confidence": 0.0-1.0}]

      マッピングできないヘッダーはtarget_table: null, target_column: null, confidence: 0.0としてください。
      JSON配列のみを出力してください。
    PROMPT
  end
end
