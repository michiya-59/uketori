# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocumentConverter do
  let!(:tenant) { create(:tenant) }
  let!(:user) { create(:user, :owner, tenant: tenant) }
  let!(:customer) { create(:customer, tenant: tenant) }

  describe ".call" do
    context "見積書→請求書の場合" do
      let!(:estimate) do
        create(:document, tenant: tenant, customer: customer, created_by_user: user,
               document_type: "estimate", status: "draft")
      end

      before do
        create(:document_item, document: estimate, name: "品目A",
               quantity: 2, unit_price: 10_000, tax_rate: 10.0, sort_order: 0)
      end

      it "請求書が作成されること" do
        result = described_class.call(estimate, "invoice", user: user, tenant: tenant)

        expect(result.document_type).to eq("invoice")
        expect(result.status).to eq("draft")
        expect(result.payment_status).to eq("unpaid")
        expect(result.parent_document_id).to eq(estimate.id)
      end

      it "明細行がコピーされること" do
        result = described_class.call(estimate, "invoice", user: user, tenant: tenant)

        expect(result.document_items.count).to eq(1)
        expect(result.document_items.first.name).to eq("品目A")
      end

      it "新しい帳票番号が採番されること" do
        result = described_class.call(estimate, "invoice", user: user, tenant: tenant)

        expect(result.document_number).not_to eq(estimate.document_number)
        expect(result.document_number).to start_with("INV-")
      end

      it "バージョンが作成されること" do
        result = described_class.call(estimate, "invoice", user: user, tenant: tenant)

        expect(result.document_versions.count).to eq(1)
        expect(result.document_versions.first.change_reason).to include("変換")
      end

      it "金額が計算されること" do
        result = described_class.call(estimate, "invoice", user: user, tenant: tenant)

        expect(result.total_amount).to be > 0
      end
    end

    context "見積書→発注書の場合" do
      let!(:estimate) do
        create(:document, tenant: tenant, customer: customer, created_by_user: user,
               document_type: "estimate")
      end

      it "発注書が作成されること" do
        result = described_class.call(estimate, "purchase_order", user: user, tenant: tenant)

        expect(result.document_type).to eq("purchase_order")
      end
    end

    context "発注書→納品書の場合" do
      let!(:po) do
        create(:document, tenant: tenant, customer: customer, created_by_user: user,
               document_type: "purchase_order")
      end

      it "納品書が作成されること" do
        result = described_class.call(po, "delivery_note", user: user, tenant: tenant)

        expect(result.document_type).to eq("delivery_note")
      end
    end

    context "不正な変換の場合" do
      let!(:receipt) do
        create(:document, tenant: tenant, customer: customer, created_by_user: user,
               document_type: "receipt")
      end

      it "ConversionErrorが発生すること" do
        expect {
          described_class.call(receipt, "invoice", user: user, tenant: tenant)
        }.to raise_error(DocumentConverter::ConversionError)
      end
    end

    context "見積書→領収書の場合" do
      let!(:estimate) do
        create(:document, tenant: tenant, customer: customer, created_by_user: user,
               document_type: "estimate")
      end

      it "ConversionErrorが発生すること" do
        expect {
          described_class.call(estimate, "receipt", user: user, tenant: tenant)
        }.to raise_error(DocumentConverter::ConversionError)
      end
    end
  end
end
