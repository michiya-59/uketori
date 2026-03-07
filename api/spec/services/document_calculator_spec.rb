# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocumentCalculator do
  let!(:tenant) { create(:tenant) }
  let!(:user) { create(:user, :owner, tenant: tenant) }
  let!(:customer) { create(:customer, tenant: tenant) }
  let!(:document) do
    create(:document, tenant: tenant, customer: customer, created_by_user: user,
           document_type: "invoice", payment_status: "unpaid")
  end

  describe ".call" do
    context "通常の明細行がある場合" do
      before do
        create(:document_item, document: document, name: "品目A",
               quantity: 2, unit_price: 10_000, tax_rate: 10.0, sort_order: 0)
        create(:document_item, document: document, name: "品目B",
               quantity: 1, unit_price: 5_000, tax_rate: 8.0, sort_order: 1)
      end

      it "小計・税額・合計が正しく計算されること" do
        result = described_class.call(document)

        # 品目A: 2 × 10,000 = 20,000 (税: 2,000)
        # 品目B: 1 × 5,000 = 5,000 (税: 400)
        expect(result.subtotal).to eq(25_000)
        expect(result.tax_amount).to eq(2_400)
        expect(result.total_amount).to eq(27_400)
        expect(result.remaining_amount).to eq(27_400)
      end

      it "税率別サマリーが正しく生成されること" do
        result = described_class.call(document)

        summary = result.tax_summary
        expect(summary.length).to eq(2)

        rate_10 = summary.find { |s| s["rate"] == 10.0 }
        expect(rate_10["subtotal"]).to eq(20_000)
        expect(rate_10["tax"]).to eq(2_000)

        rate_8 = summary.find { |s| s["rate"] == 8.0 }
        expect(rate_8["subtotal"]).to eq(5_000)
        expect(rate_8["tax"]).to eq(400)
      end
    end

    context "明細行に小数量がある場合" do
      before do
        create(:document_item, document: document, name: "時間単価",
               quantity: 1.5, unit_price: 3_333, tax_rate: 10.0)
      end

      it "切り捨て計算されること" do
        result = described_class.call(document)

        # 1.5 × 3,333 = 4,999.5 → floor → 4,999
        expect(result.subtotal).to eq(4_999)
        # 4,999 × 10% = 499.9 → floor → 499
        expect(result.tax_amount).to eq(499)
      end
    end

    context "入金がある場合" do
      before do
        create(:document_item, document: document, name: "品目",
               quantity: 1, unit_price: 100_000, tax_rate: 10.0)
        PaymentRecord.create!(
          tenant: tenant, document: document, amount: 50_000,
          payment_date: Date.current, payment_method: "bank_transfer",
          recorded_by_user_id: user.id, uuid: SecureRandom.uuid
        )
      end

      it "残額が正しく計算されること" do
        result = described_class.call(document)

        expect(result.total_amount).to eq(110_000)
        expect(result.paid_amount).to eq(50_000)
        expect(result.remaining_amount).to eq(60_000)
      end
    end

    context "割引行がある場合" do
      before do
        create(:document_item, document: document, name: "品目",
               quantity: 1, unit_price: 10_000, tax_rate: 10.0, item_type: "normal")
        create(:document_item, document: document, name: "値引き",
               quantity: 1, unit_price: -1_000, tax_rate: 10.0, item_type: "discount")
      end

      it "割引行は合計に含まれないこと" do
        result = described_class.call(document)

        # discount行はitem_type="discount"なので計算から除外
        expect(result.subtotal).to eq(10_000)
      end
    end
  end
end
