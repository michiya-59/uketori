# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocumentNumberGenerator do
  let!(:tenant) { create(:tenant, document_sequence_format: "{prefix}-{YYYY}{MM}-{SEQ}") }
  let!(:user) { create(:user, :owner, tenant: tenant) }
  let!(:customer) { create(:customer, tenant: tenant) }

  describe ".call" do
    context "帳票が存在しない場合" do
      it "シーケンス1番から開始されること" do
        result = described_class.call(tenant, "invoice", issue_date: Date.new(2026, 3, 15))

        expect(result).to eq("INV-202603-0001")
      end
    end

    context "既存の帳票がある場合" do
      before do
        create(:document, tenant: tenant, customer: customer, created_by_user: user,
               document_type: "invoice", document_number: "INV-202603-0003")
      end

      it "次のシーケンス番号が使用されること" do
        result = described_class.call(tenant, "invoice", issue_date: Date.new(2026, 3, 15))

        expect(result).to eq("INV-202603-0004")
      end
    end

    context "見積書の場合" do
      it "ESTプレフィックスが使用されること" do
        result = described_class.call(tenant, "estimate")

        expect(result).to start_with("EST-")
      end
    end

    context "カスタムフォーマットの場合" do
      before { tenant.update!(document_sequence_format: "{prefix}/{YY}-{SEQ}") }

      it "カスタムフォーマットが適用されること" do
        result = described_class.call(tenant, "invoice", issue_date: Date.new(2026, 3, 15))

        expect(result).to eq("INV/26-0001")
      end
    end
  end
end
