# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocumentMailer do
  let!(:tenant) { create(:tenant, name: "テスト株式会社") }
  let!(:user) { create(:user, :owner, tenant: tenant) }
  let!(:customer) { create(:customer, tenant: tenant, company_name: "顧客株式会社", email: "customer@example.com") }
  let!(:document) do
    create(:document, tenant: tenant, customer: customer, created_by_user: user,
           document_type: "invoice", payment_status: "unpaid",
           total_amount: 110_000, pdf_url: "https://example.com/test.pdf")
  end

  describe "#send_document" do
    let!(:mail) { described_class.send_document(document, "customer@example.com") }

    it "正しい宛先に送信されること" do
      expect(mail.to).to eq(["customer@example.com"])
    end

    it "件名にテナント名と帳票番号が含まれること" do
      expect(mail.subject).to include("テスト株式会社")
      expect(mail.subject).to include(document.document_number)
      expect(mail.subject).to include("請求書")
    end

    it "本文に顧客名が含まれること" do
      expect(mail.body.encoded).to include("顧客株式会社")
    end

    it "本文にPDFのURLが含まれること" do
      expect(mail.body.encoded).to include("https://example.com/test.pdf")
    end

    context "カスタム件名と本文がある場合" do
      let!(:mail) do
        described_class.send_document(
          document, "customer@example.com",
          subject: "カスタム件名",
          body: "カスタム本文です"
        )
      end

      it "カスタム件名が使用されること" do
        expect(mail.subject).to eq("カスタム件名")
      end

      it "カスタム本文が含まれること" do
        expect(mail.body.encoded).to include("カスタム本文です")
      end
    end
  end
end
