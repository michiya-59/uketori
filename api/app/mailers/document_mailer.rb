# frozen_string_literal: true

# 帳票メールを送信するメーラー
#
# 見積書・請求書等のPDFをダウンロードリンク付きで
# 顧客に送信する。
class DocumentMailer < ApplicationMailer
  # 帳票種別の日本語表記
  DOC_TYPE_LABELS = {
    "estimate" => "見積書",
    "purchase_order" => "発注書",
    "order_confirmation" => "注文請書",
    "delivery_note" => "納品書",
    "invoice" => "請求書",
    "receipt" => "領収書"
  }.freeze

  # 帳票を送信する
  #
  # @param document [Document] 送信対象の帳票
  # @param recipient_email [String] 送信先メールアドレス
  # @param subject [String, nil] 件名（省略時は自動生成）
  # @param body [String, nil] 本文（省略時はテンプレート使用）
  # @return [Mail::Message]
  def send_document(document, recipient_email, subject: nil, body: nil)
    @document = document
    @tenant = document.tenant
    @customer = document.customer
    @doc_type_label = DOC_TYPE_LABELS[document.document_type] || document.document_type
    @custom_body = body
    @pdf_url = document.pdf_url

    default_subject = "【#{@tenant.name}】#{@doc_type_label}のご送付（#{document.document_number}）"

    mail(
      to: recipient_email,
      subject: subject.presence || default_subject
    )
  end
end
