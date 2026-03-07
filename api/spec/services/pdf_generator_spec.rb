# frozen_string_literal: true

require "rails_helper"

RSpec.describe PdfGenerator do
  let!(:tenant) { create(:tenant) }
  let!(:user) { create(:user, :owner, tenant: tenant) }
  let!(:customer) { create(:customer, tenant: tenant) }
  let!(:document) do
    create(:document, tenant: tenant, customer: customer, created_by_user: user,
           document_type: "invoice", payment_status: "unpaid", title: "テスト請求書")
  end

  before do
    create(:document_item, document: document, name: "品目A",
           quantity: 2, unit_price: 10_000, tax_rate: 10.0, sort_order: 0)
    create(:document_item, document: document, name: "品目B",
           quantity: 1, unit_price: 5_000, tax_rate: 8.0, sort_order: 1)
    DocumentCalculator.call(document)
  end

  describe ".call" do
    context "正常な帳票の場合" do
      it "PDFが生成されpdf_urlが設定されること" do
        result = described_class.call(document)

        expect(result.pdf_url).to be_present
        expect(result.pdf_generated_at).to be_present
      end

      it "ActiveStorage::Blobが作成されること" do
        expect {
          described_class.call(document)
        }.to change(ActiveStorage::Blob, :count).by(1)
      end
    end

    context "明細行がない場合" do
      let!(:empty_document) do
        create(:document, tenant: tenant, customer: customer, created_by_user: user,
               document_type: "estimate")
      end

      it "PDFが生成されること" do
        result = described_class.call(empty_document)

        expect(result.pdf_url).to be_present
      end
    end
  end
end
