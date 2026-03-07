# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreditScoreCalculator do
  let!(:tenant) { create(:tenant) }
  let!(:user) { create(:user, :owner, tenant: tenant) }
  let!(:customer) { create(:customer, tenant: tenant) }

  describe ".call" do
    context "取引履歴がない場合" do
      it "基準点50が返されること" do
        score = described_class.call(customer)

        expect(score).to eq(50)
      end

      it "credit_score_historiesに記録されること" do
        expect {
          described_class.call(customer)
        }.to change(CreditScoreHistory, :count).by(1)
      end

      it "顧客のcredit_scoreが更新されること" do
        described_class.call(customer)

        customer.reload
        expect(customer.credit_score).to eq(50)
        expect(customer.credit_score_updated_at).to be_present
      end
    end

    context "良好な取引履歴がある場合" do
      before do
        # 1年以上前から取引あり + 累計100万円以上
        create(:document, :invoice, tenant: tenant, customer: customer,
               created_by_user: user, payment_status: "paid",
               total_amount: 500_000, issue_date: 13.months.ago.to_date)
        create(:document, :invoice, tenant: tenant, customer: customer,
               created_by_user: user, payment_status: "paid",
               total_amount: 600_000, issue_date: 2.months.ago.to_date)
      end

      it "加点されて高スコアになること" do
        score = described_class.call(customer)

        expect(score).to be > 50
      end
    end

    context "遅延がある場合" do
      before do
        create(:document, :invoice, tenant: tenant, customer: customer,
               created_by_user: user, payment_status: "overdue",
               total_amount: 100_000, due_date: 35.days.ago.to_date,
               issue_date: 2.months.ago.to_date)
      end

      it "減点されて低スコアになること" do
        score = described_class.call(customer)

        expect(score).to be < 50
      end
    end

    context "スコアが0-100にクランプされること" do
      before do
        # 大量の遅延で大幅減点
        3.times do |i|
          create(:document, :invoice, tenant: tenant, customer: customer,
                 created_by_user: user, payment_status: "overdue",
                 total_amount: 100_000, due_date: (35 + i * 10).days.ago.to_date,
                 issue_date: (50 + i * 10).days.ago.to_date)
        end
      end

      it "0未満にならないこと" do
        score = described_class.call(customer)

        expect(score).to be >= 0
        expect(score).to be <= 100
      end
    end
  end
end
