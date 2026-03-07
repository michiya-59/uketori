# frozen_string_literal: true

# データインポート実行サービス
#
# parsed_dataとcolumn_mappingを使用して、データベースへの一括挿入を行う。
# 行ごとにバリデーションを実施し、エラー行はスキップして記録する。
#
# @example
#   result = ImportExecutor.call(import_job)
#   result # => { total: 100, success: 95, skipped: 3, error: 2 }
class ImportExecutor
  # サポートする対象テーブル
  SUPPORTED_TABLES = %w[customers customer_contacts documents document_items products projects].freeze

  class << self
    # インポートジョブを実行する
    #
    # @param import_job [ImportJob]
    # @return [Hash] { total: Integer, success: Integer, skipped: Integer, error: Integer }
    def call(import_job)
      new(import_job).execute!
    end
  end

  # @param import_job [ImportJob]
  def initialize(import_job)
    @job = import_job
    @tenant = import_job.tenant
    @user = import_job.user
    @errors = []
    @stats = { total: 0, success: 0, skipped: 0, error: 0 }
  end

  # インポートを実行する
  #
  # @return [Hash]
  def execute!
    @job.update!(status: "importing", started_at: Time.current)

    rows = @job.parsed_data["rows"] || []
    headers = @job.parsed_data["headers"] || []
    mappings = @job.column_mapping || []

    @stats[:total] = rows.size

    rows.each_with_index do |row, idx|
      import_row(headers, row, mappings, idx + 1)
    end

    finalize!
    @stats
  rescue StandardError => e
    @job.update!(status: "failed", completed_at: Time.current,
                 error_details: [{ row: 0, column: nil, message: e.message }])
    raise
  end

  private

  # 1行のデータをインポートする
  #
  # @param headers [Array<String>]
  # @param row [Array<String>]
  # @param mappings [Array<Hash>]
  # @param row_number [Integer]
  def import_row(headers, row, mappings, row_number)
    # ヘッダーとマッピングからテーブル別の属性を構築
    table_attrs = build_table_attributes(headers, row, mappings)

    # メインテーブル（customers優先）を判定
    primary_table = detect_primary_table(table_attrs)
    return skip_row(row_number, "マッピング先テーブルが不明です") unless primary_table

    case primary_table
    when "customers"
      import_customer(table_attrs, row_number)
    when "documents"
      import_document(table_attrs, row_number)
    when "products"
      import_product(table_attrs, row_number)
    when "projects"
      import_project(table_attrs, row_number)
    else
      skip_row(row_number, "未対応のテーブル: #{primary_table}")
    end
  rescue ActiveRecord::RecordInvalid => e
    record_error(row_number, nil, e.message)
  rescue StandardError => e
    record_error(row_number, nil, "予期しないエラー: #{e.message}")
  end

  # テーブル別の属性Hashを構築する
  #
  # @param headers [Array<String>]
  # @param row [Array<String>]
  # @param mappings [Array<Hash>]
  # @return [Hash<String, Hash>]
  def build_table_attributes(headers, row, mappings)
    attrs = Hash.new { |h, k| h[k] = {} }

    mappings.each do |mapping|
      source = mapping["source"] || mapping[:source]
      target_table = mapping["target_table"] || mapping[:target_table]
      target_column = mapping["target_column"] || mapping[:target_column]

      next if target_table.blank? || target_column.blank?

      idx = headers.index(source)
      next unless idx

      value = row[idx]
      attrs[target_table][target_column] = value
    end

    attrs
  end

  # メインテーブルを判定する
  #
  # @param table_attrs [Hash]
  # @return [String, nil]
  def detect_primary_table(table_attrs)
    # 優先度: customers > documents > products > projects
    %w[customers documents products projects].find { |t| table_attrs.key?(t) }
  end

  # 顧客データをインポートする
  #
  # @param table_attrs [Hash]
  # @param row_number [Integer]
  def import_customer(table_attrs, row_number)
    customer_attrs = table_attrs["customers"]
    return skip_row(row_number, "会社名が空です") if customer_attrs["company_name"].blank?

    # 既存顧客チェック（会社名で重複判定）
    existing = @tenant.customers.find_by(company_name: customer_attrs["company_name"], deleted_at: nil)
    if existing
      @stats[:skipped] += 1
      return
    end

    customer = @tenant.customers.create!(
      customer_attrs.merge("customer_type" => customer_attrs["customer_type"] || "client")
    )

    # 連絡先があれば作成
    if table_attrs.key?("customer_contacts")
      contact_attrs = table_attrs["customer_contacts"]
      if contact_attrs["name"].present? || contact_attrs["email"].present?
        customer.customer_contacts.create!(
          contact_attrs.merge("is_primary" => true)
        )
      end
    end

    @stats[:success] += 1
  end

  # 帳票データをインポートする
  #
  # @param table_attrs [Hash]
  # @param row_number [Integer]
  def import_document(table_attrs, row_number)
    doc_attrs = table_attrs["documents"]
    return skip_row(row_number, "帳票番号が空です") if doc_attrs["document_number"].blank?

    # 既存帳票チェック
    existing = @tenant.documents.find_by(document_number: doc_attrs["document_number"])
    if existing
      @stats[:skipped] += 1
      return
    end

    # 顧客の紐付け（会社名から検索）
    customer = nil
    if table_attrs.dig("customers", "company_name").present?
      customer = @tenant.customers.find_by(
        company_name: table_attrs["customers"]["company_name"], deleted_at: nil
      )
    end

    doc = @tenant.documents.create!(
      doc_attrs.merge(
        "document_type" => doc_attrs["document_type"] || "invoice",
        "status" => "draft",
        "payment_status" => "unpaid",
        "customer" => customer,
        "created_by_user" => @user,
        "remaining_amount" => doc_attrs["total_amount"]
      ).compact
    )

    @stats[:success] += 1
  end

  # 品目データをインポートする
  #
  # @param table_attrs [Hash]
  # @param row_number [Integer]
  def import_product(table_attrs, row_number)
    product_attrs = table_attrs["products"]
    return skip_row(row_number, "品目名が空です") if product_attrs["name"].blank?

    existing = @tenant.products.find_by(name: product_attrs["name"])
    if existing
      @stats[:skipped] += 1
      return
    end

    @tenant.products.create!(
      product_attrs.merge(
        "is_active" => true,
        "tax_rate_type" => product_attrs["tax_rate_type"] || "standard"
      )
    )

    @stats[:success] += 1
  end

  # 案件データをインポートする
  #
  # @param table_attrs [Hash]
  # @param row_number [Integer]
  def import_project(table_attrs, row_number)
    project_attrs = table_attrs["projects"]
    return skip_row(row_number, "案件名が空です") if project_attrs["name"].blank?

    existing = @tenant.projects.find_by(name: project_attrs["name"])
    if existing
      @stats[:skipped] += 1
      return
    end

    # 顧客の紐付け
    customer = nil
    if table_attrs.dig("customers", "company_name").present?
      customer = @tenant.customers.find_by(
        company_name: table_attrs["customers"]["company_name"], deleted_at: nil
      )
    end

    @tenant.projects.create!(
      project_attrs.merge(
        "status" => project_attrs["status"] || "negotiation",
        "customer" => customer,
        "created_by_user" => @user
      ).compact
    )

    @stats[:success] += 1
  end

  # 行をスキップしてエラー記録する
  #
  # @param row_number [Integer]
  # @param message [String]
  def skip_row(row_number, message)
    @stats[:error] += 1
    record_error(row_number, nil, message)
  end

  # エラーを記録する
  #
  # @param row [Integer]
  # @param column [String, nil]
  # @param message [String]
  def record_error(row, column, message)
    @errors << { row: row, column: column, message: message }
  end

  # インポート結果を確定する
  #
  # @return [void]
  def finalize!
    @job.update!(
      status: "completed",
      completed_at: Time.current,
      import_stats: {
        total_rows: @stats[:total],
        success_count: @stats[:success],
        error_count: @stats[:error],
        skip_count: @stats[:skipped]
      },
      error_details: @errors.presence
    )
  end
end
