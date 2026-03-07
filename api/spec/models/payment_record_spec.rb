# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentRecord do
  let!(:tenant) { create(:tenant) }
  let!(:user) { create(:user, :owner, tenant: tenant) }
  let!(:customer) { create(:customer, tenant: tenant) }
  let!(:invoice) do
    create(:document, tenant: tenant, customer: customer, created_by_user: user,
           document_type: "invoice", payment_status: "unpaid",
           total_amount: 100_000, remaining_amount: 100_000)
  end

  describe "#update_document_payment!" do
    context "一部入金の場合" do
      it "payment_statusがpartialに更新されること" do
        PaymentRecord.create!(
          tenant: tenant, document: invoice, amount: 50_000,
          payment_date: Date.current, payment_method: "bank_transfer",
          matched_by: "manual", recorded_by_user: user, uuid: SecureRandom.uuid
        )

        invoice.reload
        expect(invoice.payment_status).to eq("partial")
        expect(invoice.paid_amount).to eq(50_000)
        expect(invoice.remaining_amount).to eq(50_000)
      end
    end

    context "全額入金の場合" do
      it "payment_statusがpaidに更新されること" do
        PaymentRecord.create!(
          tenant: tenant, document: invoice, amount: 100_000,
          payment_date: Date.current, payment_method: "bank_transfer",
          matched_by: "manual", recorded_by_user: user, uuid: SecureRandom.uuid
        )

        invoice.reload
        expect(invoice.payment_status).to eq("paid")
        expect(invoice.paid_amount).to eq(100_000)
        expect(invoice.remaining_amount).to eq(0)
      end
    end

    context "入金記録削除の場合" do
      it "payment_statusがunpaidに戻ること" do
        payment = PaymentRecord.create!(
          tenant: tenant, document: invoice, amount: 100_000,
          payment_date: Date.current, payment_method: "bank_transfer",
          matched_by: "manual", recorded_by_user: user, uuid: SecureRandom.uuid
        )

        expect(invoice.reload.payment_status).to eq("paid")

        payment.destroy!
        invoice.reload
        expect(invoice.payment_status).to eq("unpaid")
        expect(invoice.paid_amount).to eq(0)
      end
    end

    context "期限超過の場合" do
      before { invoice.update!(due_date: 1.day.ago) }

      it "payment_statusがoverdueに更新されること" do
        # 入金なしで期限超過 → overdue
        # これはPaymentRecordのcallback経由で検証
        PaymentRecord.create!(
          tenant: tenant, document: invoice, amount: 10_000,
          payment_date: Date.current, payment_method: "bank_transfer",
          matched_by: "manual", recorded_by_user: user, uuid: SecureRandom.uuid
        )

        # 入金を削除して未入金に戻す→期限超過なのでoverdue
        invoice.payment_records.destroy_all
        invoice.reload
        expect(invoice.payment_status).to eq("overdue")
      end
    end
  end
end
