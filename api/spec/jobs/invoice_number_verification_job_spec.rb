# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceNumberVerificationJob do
  describe "#perform" do
    let!(:tenant) do
      t = create(:tenant)
      t.update_columns(invoice_registration_number: "T1234567890123",
                       invoice_number_verified: false,
                       invoice_number_verified_at: nil)
      t
    end

    context "テナントの番号が有効な場合" do
      before do
        allow(InvoiceNumberVerifier).to receive(:verify)
          .with("T1234567890123")
          .and_return({ valid: true, name: "株式会社サンプル" })
      end

      it "検証済みフラグがtrueになること" do
        described_class.new.perform("Tenant", tenant.id)
        tenant.reload
        expect(tenant.invoice_number_verified).to be true
        expect(tenant.invoice_number_verified_at).to be_present
      end
    end

    context "テナントの番号が無効な場合" do
      before do
        allow(InvoiceNumberVerifier).to receive(:verify)
          .with("T1234567890123")
          .and_return({ valid: false, error: "該当する事業者が見つかりません" })
      end

      it "検証済みフラグがfalseのままであること" do
        described_class.new.perform("Tenant", tenant.id)
        tenant.reload
        expect(tenant.invoice_number_verified).to be false
        expect(tenant.invoice_number_verified_at).to be_present
      end
    end

    context "顧客の番号を検証する場合" do
      let!(:customer) do
        c = create(:customer, tenant: tenant)
        c.update_columns(invoice_registration_number: "T9876543210123",
                         invoice_number_verified: false)
        c
      end

      before do
        allow(InvoiceNumberVerifier).to receive(:verify)
          .with("T9876543210123")
          .and_return({ valid: true, name: "株式会社取引先" })
      end

      it "顧客の検証済みフラグがtrueになること" do
        described_class.new.perform("Customer", customer.id)
        customer.reload
        expect(customer.invoice_number_verified).to be true
        expect(customer.invoice_number_verified_at).to be_present
      end
    end

    context "レコードが存在しない場合" do
      it "エラーなく終了すること" do
        expect { described_class.new.perform("Tenant", 0) }.not_to raise_error
      end
    end

    context "登録番号が空の場合" do
      before do
        tenant.update_columns(invoice_registration_number: nil)
      end

      it "検証をスキップすること" do
        expect(InvoiceNumberVerifier).not_to receive(:verify)
        described_class.new.perform("Tenant", tenant.id)
      end
    end

    context "不正なレコードタイプの場合" do
      it "ArgumentErrorを発生させること" do
        expect { described_class.new.perform("InvalidModel", 1) }
          .to raise_error(ArgumentError, /Invalid record type/)
      end
    end
  end
end
