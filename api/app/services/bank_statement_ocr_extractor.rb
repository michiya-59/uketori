# frozen_string_literal: true

require "base64"
require "anthropic"

# 画像・PDFから銀行明細データを抽出するサービス（ダブルパス検証）
#
# Claude Vision APIを2回呼び出し、結果を突合して信頼度を算出する。
# 2回の結果が一致した行は高信頼、不一致行は低信頼としてフラグを立てる。
#
# @example
#   result = BankStatementOcrExtractor.call(file_data, content_type: "image/jpeg")
#   result[:rows]  # => [{ date:, description:, amount:, confidence:, warning: }, ...]
class BankStatementOcrExtractor
  # OCR抽出エラー
  class ExtractionError < StandardError; end

  SUPPORTED_TYPES = %w[
    image/jpeg image/jpg image/png image/gif image/webp
    application/pdf
  ].freeze

  MAX_FILE_SIZE = 20 * 1024 * 1024 # 20MB

  class << self
    # 画像・PDFから銀行明細データを抽出する（ダブルパス検証）
    #
    # @param file_data [String] ファイルのバイナリデータ
    # @param content_type [String] MIMEタイプ
    # @param filename [String] ファイル名（ログ用）
    # @return [Hash] { rows: Array<Hash>, warnings_count: Integer }
    # @raise [ExtractionError] 抽出に失敗した場合
    def call(file_data, content_type:, filename: "")
      new(file_data, content_type: content_type, filename: filename).extract!
    end

    # 対応するMIMEタイプか判定する
    #
    # @param content_type [String]
    # @return [Boolean]
    def supported?(content_type)
      SUPPORTED_TYPES.include?(content_type&.downcase)
    end
  end

  # @param file_data [String]
  # @param content_type [String]
  # @param filename [String]
  def initialize(file_data, content_type:, filename: "")
    @file_data = file_data
    @content_type = content_type.downcase
    @filename = filename
  end

  # ダブルパス検証で明細データを抽出する
  #
  # @return [Hash] { rows: Array<Hash>, warnings_count: Integer }
  # @raise [ExtractionError] 抽出に失敗した場合
  def extract!
    validate!

    # 1回目のAI呼び出し
    response1 = call_vision_api(pass: 1)
    raise ExtractionError, "AIからの応答が空です" if response1.blank?
    rows1 = parse_response(response1)

    # 2回目のAI呼び出し（温度を変えて独立した結果を得る）
    response2 = call_vision_api(pass: 2)
    rows2 = response2.present? ? parse_response(response2) : []

    # 両方とも空の場合
    if rows1.empty? && rows2.empty?
      raise ExtractionError, "明細データを抽出できませんでした。画像が鮮明か確認してください"
    end

    # 突合して信頼度を算出
    verified_rows = verify_rows(rows1, rows2)
    warnings_count = verified_rows.count { |r| r[:warning].present? }

    { rows: verified_rows, warnings_count: warnings_count }
  end

  private

  # 入力を検証する
  #
  # @return [void]
  # @raise [ExtractionError]
  def validate!
    raise ExtractionError, "ファイルデータが空です" if @file_data.blank?
    raise ExtractionError, "非対応のファイル形式です（JPEG/PNG/PDF に対応）" unless self.class.supported?(@content_type)
    raise ExtractionError, "ファイルサイズが上限（20MB）を超えています" if @file_data.bytesize > MAX_FILE_SIZE

    unless ai_available?
      raise ExtractionError, "AI機能が利用できません（APIキー未設定）"
    end
  end

  # Claude Vision APIを呼び出す
  #
  # @param pass [Integer] パス番号（1または2）
  # @return [String] APIレスポンスのテキスト
  # @raise [ExtractionError]
  def call_vision_api(pass:)
    client = Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"])

    media_type = @content_type == "application/pdf" ? "application/pdf" : @content_type

    content = [
      {
        type: @content_type == "application/pdf" ? "document" : "image",
        source: {
          type: "base64",
          media_type: media_type,
          data: encoded_data
        }
      },
      {
        type: "text",
        text: extraction_prompt(pass: pass)
      }
    ]

    # 2回目は温度を変えて独立性を高める
    params = {
      model: "claude-haiku-4-5-20251001",
      max_tokens: 4096,
      messages: [{ role: "user", content: content }]
    }
    params[:temperature] = pass == 1 ? 0.0 : 0.2

    response = client.messages.create(**params)
    response.content.first.text
  rescue StandardError => e
    if pass == 2
      Rails.logger.warn("BankStatementOcrExtractor pass 2 error: #{e.class} - #{e.message}")
      return nil
    end
    Rails.logger.error("BankStatementOcrExtractor error: #{e.class} - #{e.message}")
    raise ExtractionError, "AI処理に失敗しました: #{e.message}"
  end

  # Base64エンコード済みデータ（キャッシュ）
  #
  # @return [String]
  def encoded_data
    @encoded_data ||= Base64.strict_encode64(@file_data)
  end

  # 抽出用プロンプト
  #
  # @param pass [Integer] パス番号
  # @return [String]
  def extraction_prompt(pass:)
    base = <<~PROMPT
      この画像/PDFは銀行の取引明細（通帳、ネットバンキング画面、PDF明細書など）です。
      各取引行から以下の情報を正確に読み取り、CSVフォーマットで出力してください。

      【出力ルール】
      - 1行目はヘッダー行: 取引日,摘要,金額
      - 2行目以降にデータ行を記載
      - 取引日は YYYY/MM/DD 形式に統一（和暦は西暦に変換）
      - 金額は数値のみ（カンマ・円記号なし）、入金のみ抽出（出金は除外）
      - 摘要は振込人名や取引内容をそのまま記載
      - 読み取れない文字は「?」で代替
      - 入金が0件の場合は「NO_DATA」とだけ出力

      【重要】
      - 正確性を最優先してください。1桁の誤りも許されません
      - 金額は特に慎重に、1文字ずつ確認してから出力してください
      - 出金（引き落とし・振込など支出）は除外し、入金のみ出力してください
      - CSV以外のテキスト（説明文など）は一切出力しないでください
    PROMPT

    if pass == 2
      base += <<~EXTRA

        【追加指示】
        もう一度、画像を最初から注意深く読み取ってください。
        特に金額の各桁を1つずつ確認し、摘要の文字も正確に読み取ってください。
      EXTRA
    end

    base + "\nCSVデータのみを出力:"
  end

  # 2回の抽出結果を突合して信頼度を算出する
  #
  # @param rows1 [Array<Array<String>>] 1回目の結果
  # @param rows2 [Array<Array<String>>] 2回目の結果
  # @return [Array<Hash>] 検証済み行データ
  def verify_rows(rows1, rows2)
    # 2回目が空の場合（API失敗など）は1回目のみで低信頼
    if rows2.empty?
      return rows1.map do |row|
        {
          date: row[0],
          description: row[1],
          amount: row[2],
          confidence: "medium",
          warning: "検証未実施（1回のみ抽出）"
        }
      end
    end

    # rows2をインデックスで引ける形にする
    verified = []

    rows1.each_with_index do |row1, idx|
      row2 = rows2[idx]

      if row2.nil?
        # 2回目に対応行がない
        verified << build_row(row1, "low", "2回目の抽出で該当行なし")
        next
      end

      date_match = row1[0] == row2[0]
      desc_match = normalize_desc(row1[1]) == normalize_desc(row2[1])
      amount_match = row1[2] == row2[2]

      if date_match && amount_match && desc_match
        # 完全一致 → 高信頼
        verified << build_row(row1, "high", nil)
      elsif date_match && amount_match
        # 日付・金額一致、摘要のみ差異 → 中信頼
        verified << build_row(row1, "medium", "摘要の読み取りに差異あり（#{row2[1]}）")
      elsif date_match && desc_match
        # 金額不一致 → 低信頼（要確認）
        verified << build_row(row1, "low", "金額の読み取りに差異あり（1回目: #{row1[2]}, 2回目: #{row2[2]}）")
      else
        # 大きな不一致 → 低信頼
        verified << build_row(row1, "low", "2回の読み取り結果に大きな差異あり")
      end
    end

    # 2回目にだけ存在する行（1回目が見逃した可能性）
    if rows2.length > rows1.length
      rows2[rows1.length..].each do |extra_row|
        verified << build_row(extra_row, "low", "1回目の抽出で検出されなかった行")
      end
    end

    verified
  end

  # 検証済み行データを構築する
  #
  # @param row [Array<String>]
  # @param confidence [String] high/medium/low
  # @param warning [String, nil]
  # @return [Hash]
  def build_row(row, confidence, warning)
    {
      date: row[0],
      description: row[1],
      amount: row[2],
      confidence: confidence,
      warning: warning
    }
  end

  # 摘要を正規化して比較用にする
  #
  # @param desc [String]
  # @return [String]
  def normalize_desc(desc)
    desc.to_s.gsub(/[\s　]/, "").gsub(/[（）()）]/, "")
  end

  # AIレスポンスをCSV行にパースする
  #
  # @param text [String]
  # @return [Array<Array<String>>]
  def parse_response(text)
    return [] if text.strip == "NO_DATA"

    lines = text.strip.split("\n").map(&:strip).reject(&:blank?)

    # ヘッダー行をスキップ
    start_index = 0
    if lines.first&.match?(/取引日|日付|date/i)
      start_index = 1
    end

    rows = []
    lines[start_index..].each do |line|
      # CSVコードブロックの囲みをスキップ
      next if line.start_with?("```")

      cols = line.split(",").map(&:strip)
      next if cols.length < 3

      date_str = cols[0]
      description = cols[1]
      amount_str = cols[2]

      # 日付っぽいかチェック
      next unless date_str.match?(%r{\A\d{4}[/\-]\d{1,2}[/\-]\d{1,2}\z})

      # 金額が数値かチェック
      cleaned_amount = amount_str.gsub(/[,¥￥\s]/, "")
      next unless cleaned_amount.match?(/\A\d+\z/)

      rows << [date_str, description, cleaned_amount]
    end

    rows
  end

  # Claude APIが利用可能かチェックする
  #
  # @return [Boolean]
  def ai_available?
    ENV["ANTHROPIC_API_KEY"].present?
  end
end
