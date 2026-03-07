# frozen_string_literal: true

require "csv"

# 銀行明細CSVをインポートするサービス
#
# Shift_JIS / UTF-8 を自動判定してCSVをパースし、
# 重複チェック後に bank_statements テーブルに保存する。
#
# @example
#   result = BankStatementImporter.call(tenant, csv_content, filename: "mufg_202602.csv")
#   result[:imported] # => 50
#   result[:skipped]  # => 3
class BankStatementImporter
  # インポートエラー
  class ImportError < StandardError; end

  # 対応する銀行フォーマットのパーサー定義
  BANK_FORMATS = {
    "generic" => { date_col: 0, desc_col: 1, amount_col: 2, payer_col: nil, balance_col: nil },
    "mufg" => { date_col: 0, desc_col: 2, amount_col: 3, payer_col: 2, balance_col: 5 },
    "smbc" => { date_col: 0, desc_col: 2, amount_col: 3, payer_col: 2, balance_col: 5 },
    "mizuho" => { date_col: 0, desc_col: 2, amount_col: 3, payer_col: 2, balance_col: 5 },
    "rakuten" => { date_col: 0, desc_col: 1, amount_col: 2, payer_col: 1, balance_col: 3 }
  }.freeze

  class << self
    # 銀行明細CSVをインポートする
    #
    # @param tenant [Tenant] テナント
    # @param csv_data [String] CSV文字列データ
    # @param filename [String] ファイル名（銀行フォーマット判定用）
    # @param bank_format [String] 銀行フォーマット（指定時はauto-detectionスキップ）
    # @return [Hash] { imported: Integer, skipped: Integer, batch_id: String }
    def call(tenant, csv_data, filename: "", bank_format: nil)
      new(tenant, csv_data, filename: filename, bank_format: bank_format).import!
    end
  end

  # @param tenant [Tenant]
  # @param csv_data [String]
  # @param filename [String]
  # @param bank_format [String, nil]
  def initialize(tenant, csv_data, filename: "", bank_format: nil)
    @tenant = tenant
    @csv_data = csv_data
    @filename = filename
    @bank_format = bank_format || detect_bank_format(filename)
  end

  # CSVをパースしてインポートする
  #
  # @return [Hash] インポート結果
  # @raise [ImportError] CSVパースに失敗した場合
  def import!
    encoded_data = ensure_utf8(@csv_data)
    rows = parse_csv(encoded_data)

    raise ImportError, "CSVにデータ行がありません" if rows.empty?

    batch_id = SecureRandom.uuid
    imported = 0
    skipped = 0

    rows.each do |row|
      record = build_record(row, batch_id)
      next if record.nil?

      if duplicate?(record)
        skipped += 1
        next
      end

      record.save!
      imported += 1
    end

    { imported: imported, skipped: skipped, batch_id: batch_id }
  rescue CSV::MalformedCSVError => e
    raise ImportError, "CSVフォーマットが不正です: #{e.message}"
  end

  private

  # 文字コードをUTF-8に変換する
  #
  # @param data [String]
  # @return [String] UTF-8文字列
  def ensure_utf8(data)
    dup = data.dup
    dup.force_encoding("UTF-8")
    return dup if dup.valid_encoding?

    data.dup.force_encoding("Shift_JIS").encode("UTF-8", invalid: :replace, undef: :replace)
  end

  # CSVをパースする
  #
  # @param data [String]
  # @return [Array<Array<String>>]
  def parse_csv(data)
    rows = CSV.parse(data, liberal_parsing: true)
    # ヘッダー行をスキップ（最初の行が日付でなければヘッダーとみなす）
    return rows[1..] || [] if rows.any? && !date_like?(rows[0]&.first)

    rows
  end

  # ファイル名から銀行フォーマットを推定する
  #
  # @param filename [String]
  # @return [String]
  def detect_bank_format(filename)
    name = filename.downcase
    return "mufg" if name.include?("mufg") || name.include?("三菱")
    return "smbc" if name.include?("smbc") || name.include?("三井")
    return "mizuho" if name.include?("mizuho") || name.include?("みずほ")
    return "rakuten" if name.include?("rakuten") || name.include?("楽天")

    "generic"
  end

  # CSV行からBankStatementレコードを構築する
  #
  # @param row [Array<String>]
  # @param batch_id [String]
  # @return [BankStatement, nil]
  def build_record(row, batch_id)
    format = BANK_FORMATS[@bank_format] || BANK_FORMATS["generic"]
    date_str = row[format[:date_col]]&.strip
    description = row[format[:desc_col]]&.strip
    amount_str = row[format[:amount_col]]&.strip

    return nil if date_str.blank? || amount_str.blank?

    date = parse_date(date_str)
    return nil if date.nil?

    amount = parse_amount(amount_str)
    return nil if amount.nil? || amount <= 0

    payer_name = format[:payer_col] ? row[format[:payer_col]]&.strip : nil
    balance = format[:balance_col] ? parse_amount(row[format[:balance_col]]&.strip) : nil

    BankStatement.new(
      tenant: @tenant,
      transaction_date: date,
      description: description || "",
      payer_name: payer_name,
      amount: amount,
      balance: balance,
      bank_name: @bank_format == "generic" ? nil : @bank_format.upcase,
      import_batch_id: batch_id,
      is_matched: false,
      raw_data: { row: row }
    )
  end

  # 重複チェック
  #
  # @param record [BankStatement]
  # @return [Boolean]
  def duplicate?(record)
    BankStatement.where(
      tenant: @tenant,
      transaction_date: record.transaction_date,
      amount: record.amount,
      description: record.description
    ).exists?
  end

  # 日付文字列をパースする
  #
  # @param str [String]
  # @return [Date, nil]
  def parse_date(str)
    return nil if str.blank?

    # yyyy/mm/dd, yyyy-mm-dd, yyyy年mm月dd日
    cleaned = str.gsub(/[年月]/, "/").gsub("日", "").strip
    Date.parse(cleaned)
  rescue Date::Error, ArgumentError
    nil
  end

  # 金額文字列を整数に変換する
  #
  # @param str [String]
  # @return [Integer, nil]
  def parse_amount(str)
    return nil if str.blank?

    # カンマ・円記号・スペースを除去
    cleaned = str.gsub(/[,¥￥\s]/, "")
    return nil unless cleaned.match?(/\A-?\d+\z/)

    cleaned.to_i.abs
  end

  # 文字列が日付っぽいか判定する
  #
  # @param str [String, nil]
  # @return [Boolean]
  def date_like?(str)
    return false if str.nil?

    str.strip.match?(%r{\A\d{4}[/\-年]})
  end
end
