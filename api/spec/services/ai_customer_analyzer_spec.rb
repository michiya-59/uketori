# frozen_string_literal: true

require "rails_helper"

RSpec.describe AiCustomerAnalyzer do
  let!(:tenant) { create(:tenant, plan: "standard") }
  let!(:user) { create(:user, :owner, tenant: tenant) }
  let!(:customer) { create(:customer, tenant: tenant, credit_score: 65) }

  describe ".call" do
    context "取引データがある場合" do
      let!(:paid_invoice) do
        create(:document, :invoice,
               tenant: tenant, customer: customer, created_by_user: user,
               issue_date: 2.months.ago.to_date,
               total_amount: 500_000, paid_amount: 500_000,
               status: "sent", payment_status: "paid")
      end
      let!(:overdue_invoice) do
        create(:document, :invoice,
               tenant: tenant, customer: customer, created_by_user: user,
               issue_date: 1.month.ago.to_date, due_date: 15.days.ago.to_date,
               total_amount: 300_000, paid_amount: 0, remaining_amount: 300_000,
               status: "sent", payment_status: "overdue")
      end

      it "分析結果を返すこと" do
        result = described_class.call(customer)

        expect(result[:customer_id]).to eq(customer.uuid)
        expect(result[:company_name]).to eq(customer.company_name)
        expect(result[:credit_score]).to eq(65)
        expect(result).to have_key(:statistics)
        expect(result).to have_key(:payment_history)
        expect(result).to have_key(:risk_assessment)
        expect(result).to have_key(:summary)
        expect(result).to have_key(:recommendations)
        expect(result).to have_key(:confidence)
      end

      it "統計データが正確であること" do
        result = described_class.call(customer)
        stats = result[:statistics]

        expect(stats[:total_invoiced]).to eq(800_000)
        expect(stats[:total_paid]).to eq(500_000)
        expect(stats[:invoice_count]).to eq(2)
        expect(stats[:overdue_count]).to eq(1)
      end

      it "月次支払い履歴が12ヶ月分あること" do
        result = described_class.call(customer)
        expect(result[:payment_history]).to be_an(Array)
        expect(result[:payment_history].length).to eq(12)
      end

      it "リスク評価が有効な値であること" do
        result = described_class.call(customer)
        expect(%w[low medium high critical]).to include(result[:risk_assessment])
      end
    end

    context "取引データがない場合" do
      it "空のデータでも結果を返すこと" do
        result = described_class.call(customer)

        expect(result[:customer_id]).to eq(customer.uuid)
        expect(result[:statistics][:invoice_count]).to eq(0)
        expect(result[:statistics][:total_invoiced]).to eq(0)
        expect(result).to have_key(:risk_assessment)
      end
    end

    context "与信スコアが低い顧客の場合" do
      let!(:high_risk_customer) { create(:customer, tenant: tenant, credit_score: 15) }

      it "高リスク判定になること" do
        result = described_class.call(high_risk_customer)
        expect(%w[high critical]).to include(result[:risk_assessment])
      end
    end

    context "与信スコア履歴がある場合" do
      before do
        customer.credit_score_histories.create!(
          tenant: tenant, score: 70,
          factors: [], calculated_at: 1.month.ago
        )
        customer.credit_score_histories.create!(
          tenant: tenant, score: 65,
          factors: [], calculated_at: Time.current
        )
      end

      it "トレンドデータが含まれること" do
        result = described_class.call(customer)
        expect(result[:credit_score_trend]).to be_an(Array)
        expect(result[:credit_score_trend].length).to eq(2)
      end
    end
  end
end
