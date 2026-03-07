# frozen_string_literal: true

require "prawn"
require "prawn/table"

# 帳票PDFを生成するサービス
#
# Prawnを使用してインボイス制度対応のPDFを生成し、
# ActiveStorageにアップロードしてURLを返却する。
#
# @example
#   result = PdfGenerator.call(document)
#   result.pdf_url # => "blob://..."
class PdfGenerator
  # 帳票種別の日本語表記
  DOC_TYPE_LABELS = {
    "estimate" => "見積書",
    "purchase_order" => "発注書",
    "order_confirmation" => "注文請書",
    "delivery_note" => "納品書",
    "invoice" => "請求書",
    "receipt" => "領収書"
  }.freeze

  # レイアウト定数
  PAGE_WIDTH = 515.28 # A4 width - margins(40+40)

  class << self
    # 帳票のPDFを生成してStorageにアップロードする
    #
    # @param document [Document] 対象帳票
    # @return [Document] pdf_url更新済みの帳票
    def call(document)
      new(document).generate!
    end
  end

  # @param document [Document]
  def initialize(document)
    @document = document.reload
    @tenant = document.tenant
    @customer = document.customer
    @items = document.document_items.order(:sort_order)
  end

  # PDFを生成してアップロードし、帳票のpdf_urlにblobキーを保存する
  #
  # @return [Document] 更新済みの帳票
  def generate!
    pdf = build_pdf
    pdf_data = pdf.render

    filename = "#{@document.document_number.gsub('/', '_')}_#{Time.current.strftime('%Y%m%d%H%M%S')}.pdf"
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(pdf_data),
      filename: filename,
      content_type: "application/pdf"
    )

    @document.update!(
      pdf_url: "blob://#{blob.key}",
      pdf_generated_at: Time.current
    )

    @document
  end

  private

  # Prawn::Documentを構築する
  #
  # @return [Prawn::Document]
  def build_pdf
    pdf = Prawn::Document.new(page_size: "A4", margin: [40, 40, 40, 40])
    register_fonts(pdf)
    render_header(pdf)
    render_addresses(pdf)
    render_dates(pdf)
    render_total_banner(pdf)
    render_items_table(pdf)
    render_tax_summary_and_totals(pdf)
    render_bank_info(pdf) if @document.document_type == "invoice"
    render_notes(pdf)
    render_footer(pdf)
    pdf
  end

  # 日本語フォントを登録する
  #
  # @param pdf [Prawn::Document]
  # @return [void]
  def register_fonts(pdf)
    font_path = Rails.root.join("app", "assets", "fonts")
    if File.exist?(font_path.join("NotoSansJP-Regular.ttf"))
      pdf.font_families.update(
        "NotoSansJP" => {
          normal: font_path.join("NotoSansJP-Regular.ttf").to_s,
          bold: font_path.join("NotoSansJP-Bold.ttf").to_s
        }
      )
      pdf.font "NotoSansJP"
    end
  end

  # ヘッダー（帳票タイトル・番号）を描画する
  #
  # @param pdf [Prawn::Document]
  # @return [void]
  def render_header(pdf)
    doc_label = DOC_TYPE_LABELS[@document.document_type] || @document.document_type
    pdf.text doc_label, size: 22, style: :bold, align: :center
    pdf.move_down 4
    pdf.text "No. #{@document.document_number}", size: 10, align: :center, color: "666666"
    pdf.move_down 20
  end

  # 宛先と自社情報を横並びで描画する
  #
  # @param pdf [Prawn::Document]
  # @return [void]
  def render_addresses(pdf)
    left_width = 260
    right_width = PAGE_WIDTH - left_width

    # 左側: 宛先
    left_header = "#{@customer.company_name} 御中"
    left_details = []
    left_details << @customer.department if @customer.department.present?
    left_details << "#{@customer.contact_name} 様" if @customer.contact_name.present?
    address = build_address(@customer)
    left_details << address if address.present?

    # 右側: 自社情報
    right_header = @tenant.name
    right_details = []
    tenant_address = build_tenant_address
    right_details << tenant_address if tenant_address.present?
    right_details << "TEL: #{@tenant.phone}" if @tenant.phone.present?
    right_details << "登録番号: #{@tenant.invoice_registration_number}" if @tenant.invoice_registration_number.present?

    # 2行構成のテーブルで左右並列レイアウト（重なりを完全回避）
    rows = []

    # 1行目: 会社名（太字）
    rows << [
      { content: left_header, font_style: :bold, size: 13, padding: [0, 5, 4, 0] },
      { content: right_header, font_style: :bold, size: 10, align: :right, padding: [3, 0, 4, 5] }
    ]

    # 2行目: 詳細情報（住所・連絡先）
    if left_details.any? || right_details.any?
      rows << [
        { content: left_details.join("\n"), size: 8, text_color: "444444", padding: [2, 5, 0, 0] },
        { content: right_details.join("\n"), size: 8, text_color: "444444", align: :right, padding: [2, 0, 0, 5] }
      ]
    end

    pdf.table(
      rows,
      column_widths: [left_width, right_width],
      cell_style: { borders: [] }
    )

    pdf.move_down 8

    # 下線
    pdf.stroke_color "CCCCCC"
    pdf.stroke_horizontal_rule
    pdf.stroke_color "000000"
    pdf.move_down 12
  end

  # 日付情報を描画する
  #
  # @param pdf [Prawn::Document]
  # @return [void]
  def render_dates(pdf)
    date_items = []
    date_items << ["発行日", format_date(@document.issue_date)]
    date_items << ["支払期限", format_date(@document.due_date)] if @document.due_date.present?
    date_items << ["有効期限", format_date(@document.valid_until)] if @document.valid_until.present?

    pdf.table(
      date_items,
      cell_style: { borders: [], size: 9, padding: [2, 8, 2, 0] },
      column_widths: [70, 150]
    ) do |t|
      t.columns(0).font_style = :bold
    end

    pdf.move_down 12
  end

  # 合計金額バナーを描画する
  #
  # @param pdf [Prawn::Document]
  # @return [void]
  def render_total_banner(pdf)
    pdf.fill_color "F5F5F5"
    pdf.fill_rectangle [0, pdf.cursor], PAGE_WIDTH, 35
    pdf.fill_color "000000"

    pdf.move_down 8
    pdf.text "合計金額　　¥#{number_with_delimiter(@document.total_amount)}",
             size: 16, style: :bold, align: :center
    pdf.move_down 12
  end

  # 明細テーブルを描画する
  #
  # @param pdf [Prawn::Document]
  # @return [void]
  def render_items_table(pdf)
    pdf.move_down 5

    header = %w[No. 品名 数量 単位 単価 税率 金額]
    col_widths = [30, nil, 50, 40, 80, 50, 90]
    # nilの列（品名）は残り幅を自動計算
    fixed_total = col_widths.compact.sum
    col_widths[1] = PAGE_WIDTH - fixed_total

    rows = @items.each_with_index.map do |item, idx|
      [
        (idx + 1).to_s,
        item.name.to_s,
        format_number(item.quantity),
        item.unit.to_s,
        "¥#{number_with_delimiter(item.unit_price)}",
        "#{item.tax_rate}%",
        "¥#{number_with_delimiter(item.amount)}"
      ]
    end

    table_data = [header] + rows

    pdf.table(table_data, column_widths: col_widths, cell_style: { size: 9, padding: [5, 5] }) do |t|
      t.row(0).font_style = :bold
      t.row(0).background_color = "E8E8E8"
      t.row(0).align = :center
      t.columns(0).align = :center
      t.columns(2).align = :right
      t.columns(4).align = :right
      t.columns(5).align = :center
      t.columns(6).align = :right

      # 奇数行に薄い背景
      rows.size.times do |i|
        t.row(i + 1).background_color = "FAFAFA" if i.odd?
      end
    end

    pdf.move_down 15
  end

  # 税率別内訳と合計金額を右揃えで描画する
  #
  # @param pdf [Prawn::Document]
  # @return [void]
  def render_tax_summary_and_totals(pdf)
    summary_width = 280
    x_offset = PAGE_WIDTH - summary_width

    # --- 税率別内訳 ---
    summary = @document.tax_summary
    summary = JSON.parse(summary) if summary.is_a?(String)

    if summary.present?
      pdf.text "税率別内訳", size: 9, style: :bold, align: :right
      pdf.move_down 4

      tax_header = %w[税率 対象額 消費税額]
      tax_rows = summary.map do |entry|
        rate = entry["rate"] || entry[:rate]
        subtotal = entry["subtotal"] || entry[:subtotal]
        tax = entry["tax"] || entry[:tax]
        ["#{rate}%", "¥#{number_with_delimiter(subtotal)}", "¥#{number_with_delimiter(tax)}"]
      end

      pdf.indent(x_offset) do
        pdf.table(
          [tax_header] + tax_rows,
          column_widths: [70, 105, 105],
          cell_style: { size: 8, padding: [4, 6] }
        ) do |t|
          t.row(0).font_style = :bold
          t.row(0).background_color = "F0F0F0"
          t.row(0).align = :center
          t.columns(0).align = :center
          t.columns(1).align = :right
          t.columns(2).align = :right
        end
      end

      pdf.move_down 10
    end

    # --- 小計 / 消費税 / 合計 ---
    totals_data = [
      ["小計", "¥#{number_with_delimiter(@document.subtotal)}"],
      ["消費税", "¥#{number_with_delimiter(@document.tax_amount)}"],
      ["合計（税込）", "¥#{number_with_delimiter(@document.total_amount)}"]
    ]

    pdf.indent(x_offset) do
      pdf.table(
        totals_data,
        column_widths: [120, 160],
        cell_style: { size: 10, padding: [5, 8] }
      ) do |t|
        t.columns(0).font_style = :bold
        t.columns(1).align = :right
        t.row(2).size = 12
        t.row(2).font_style = :bold
        t.row(2).background_color = "F0F0F0"
      end
    end

    pdf.move_down 15
  end

  # 振込先情報を描画する（請求書のみ）
  #
  # @param pdf [Prawn::Document]
  # @return [void]
  def render_bank_info(pdf)
    return unless @tenant.bank_name.present?

    pdf.text "お振込先", size: 10, style: :bold
    pdf.move_down 4

    bank_items = []
    bank_items << ["金融機関", @tenant.bank_name]
    bank_items << ["支店名", @tenant.bank_branch_name] if @tenant.bank_branch_name.present?
    account_type = case @tenant.bank_account_type
                   when "ordinary", 0 then "普通"
                   when "current", 1 then "当座"
                   else @tenant.bank_account_type.to_s
                   end
    bank_items << ["口座種別", account_type] if @tenant.bank_account_type.present?
    bank_items << ["口座番号", @tenant.bank_account_number] if @tenant.bank_account_number.present?
    bank_items << ["口座名義", @tenant.bank_account_holder] if @tenant.bank_account_holder.present?

    pdf.table(
      bank_items,
      cell_style: { borders: [], size: 9, padding: [2, 8, 2, 0] },
      column_widths: [80, 200]
    ) do |t|
      t.columns(0).font_style = :bold
      t.columns(0).text_color = "666666"
    end

    pdf.move_down 15
  end

  # 備考欄を描画する
  #
  # @param pdf [Prawn::Document]
  # @return [void]
  def render_notes(pdf)
    return if @document.notes.blank?

    pdf.text "備考", size: 10, style: :bold
    pdf.move_down 4

    pdf.fill_color "FAFAFA"
    notes_height = pdf.height_of(@document.notes, size: 9) + 16
    pdf.fill_rectangle [0, pdf.cursor], PAGE_WIDTH, notes_height
    pdf.fill_color "000000"

    pdf.move_down 8
    pdf.indent(8) do
      pdf.text @document.notes, size: 9, color: "333333", leading: 3
    end
    pdf.move_down 15
  end

  # フッターを描画する
  #
  # @param pdf [Prawn::Document]
  # @return [void]
  def render_footer(pdf)
    pdf.number_pages "Page <page> / <total>",
                     at: [pdf.bounds.right - 100, -10],
                     size: 7,
                     color: "999999"
  end

  # 顧客住所を構築する
  #
  # @param customer [Customer]
  # @return [String, nil]
  def build_address(customer)
    parts = []
    parts << "〒#{customer.postal_code}" if customer.postal_code.present?
    addr = [customer.prefecture, customer.city, customer.address_line1].compact.join
    parts << addr if addr.present?
    parts << customer.address_line2 if customer.address_line2.present?
    parts.any? ? parts.join("\n") : nil
  end

  # テナント住所を構築する
  #
  # @return [String, nil]
  def build_tenant_address
    parts = []
    parts << "〒#{@tenant.postal_code}" if @tenant.postal_code.present?
    addr = [@tenant.prefecture, @tenant.city, @tenant.address_line1].compact.join
    parts << addr if addr.present?
    parts << @tenant.address_line2 if @tenant.address_line2.present?
    parts.any? ? parts.join("\n") : nil
  end

  # 日付をフォーマットする
  #
  # @param date [Date, nil]
  # @return [String]
  def format_date(date)
    return "" if date.nil?

    date.strftime("%Y年%m月%d日")
  end

  # 数値を3桁カンマ区切りにする
  #
  # @param number [Numeric]
  # @return [String]
  def number_with_delimiter(number)
    return "0" if number.nil?

    number.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
  end

  # 数量をフォーマットする
  #
  # @param number [Numeric]
  # @return [String]
  def format_number(number)
    return "0" if number.nil?

    number == number.to_i ? number.to_i.to_s : number.to_s
  end
end
