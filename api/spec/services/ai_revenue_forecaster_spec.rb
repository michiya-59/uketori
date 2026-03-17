# frozen_string_literal: true

require "rails_helper"

RSpec.describe AiRevenueForecaster do
  let!(:tenant) { create(:tenant, plan: "standard") }
  let!(:customer) { create(:customer, tenant: tenant) }

  describe ".call" do
    context "過去データがある場合" do
      let!(:invoices) do
        (1..6).map do |i|
          create(:document, :invoice,
                 tenant: tenant,
                 customer: customer,
                 created_by_user: create(:user, :owner, tenant: tenant),
                 issue_date: (i.months.ago).to_date,
                 total_amount: 1_000_000 + (i * 100_000),
                 paid_amount: 1_000_000 + (i * 100_000),
                 status: "sent",
                 payment_status: "paid")
        end
      end

      it "過去データと予測データを返すこと" do
        result = described_class.call(tenant, months: 3)

        expect(result).to have_key(:historical)
        expect(result).to have_key(:forecast)
        expect(result).to have_key(:commentary)
        expect(result).to have_key(:confidence)
        expect(result[:historical]).to be_an(Array)
        expect(result[:forecast]).to be_an(Array)
        expect(result[:forecast].length).to eq(3)
      end

      it "予測月数を指定できること" do
        result = described_class.call(tenant, months: 6)
        expect(result[:forecast].length).to eq(6)
      end

      it "予測値が正の整数であること" do
        result = described_class.call(tenant, months: 3)
        result[:forecast].each do |f|
          expect(f[:predicted]).to be_a(Integer)
          expect(f[:predicted]).to be >= 0
          expect(f[:month]).to match(/\A\d{4}-\d{2}\z/)
          expect(f).to have_key(:lower_bound)
          expect(f).to have_key(:upper_bound)
        end
      end
    end

    context "過去データがない場合" do
      it "空の予測を返すこと" do
        result = described_class.call(tenant, months: 3)

        expect(result[:historical]).to be_an(Array)
        expect(result[:forecast]).to be_an(Array)
        # 全て0の予測
        result[:forecast].each do |f|
          expect(f[:predicted]).to eq(0)
        end
      end
    end

    context "月数が範囲外の場合" do
      let!(:user) { create(:user, :owner, tenant: tenant) }
      let!(:invoice) do
        create(:document, :invoice, tenant: tenant, customer: customer,
               created_by_user: user, issue_date: 1.month.ago.to_date,
               total_amount: 500_000, paid_amount: 500_000, status: "sent")
      end

      it "1〜6にクランプされること" do
        result = described_class.call(tenant, months: 10)
        expect(result[:forecast].length).to eq(6)

        result2 = described_class.call(tenant, months: 0)
        expect(result2[:forecast].length).to eq(1)
      end
    end

    context "パイプラインデータがある場合" do
      let!(:user) { create(:user, :owner, tenant: tenant) }
      let!(:project) do
        create(:project, tenant: tenant, customer: customer,
               assigned_user: user, status: "negotiation",
               amount: 2_000_000, probability: 80,
               end_date: 1.month.from_now)
      end

      it "パイプラインデータが含まれること" do
        result = described_class.call(tenant, months: 3)
        expect(result[:pipeline]).to be_an(Array)
        expect(result[:pipeline].first[:name]).to eq(project.name)
      end
    end
  end
end
