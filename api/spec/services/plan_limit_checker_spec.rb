# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlanLimitChecker do
  let!(:tenant) { create(:tenant, plan: plan) }
  let!(:owner) { create(:user, :owner, tenant: tenant) }

  describe "#check!" do
    context "freeプランの場合" do
      let!(:plan) { "free" }

      it "ユーザー1名まで許可されること" do
        checker = described_class.new(tenant)
        # owner が1名いるので制限(1)に達している
        expect { checker.check!(:users) }.to raise_error(PlanLimitExceededError, /ユーザー数/)
      end

      it "顧客10社まで許可されること" do
        checker = described_class.new(tenant)
        expect(checker.check!(:customers)).to be true
      end

      it "AI消込が利用不可であること" do
        checker = described_class.new(tenant)
        expect { checker.check!(:ai_matching) }.to raise_error(PlanLimitExceededError, /ご利用いただけません/)
      end

      it "自動督促が利用不可であること" do
        checker = described_class.new(tenant)
        expect { checker.check!(:auto_dunning) }.to raise_error(PlanLimitExceededError, /ご利用いただけません/)
      end
    end

    context "starterプランの場合" do
      let!(:plan) { "starter" }

      it "ユーザー3名まで許可されること" do
        checker = described_class.new(tenant)
        expect(checker.check!(:users)).to be true
      end

      it "AI消込が利用可能であること" do
        checker = described_class.new(tenant)
        expect(checker.check!(:ai_matching)).to be true
      end
    end

    context "professionalプランの場合" do
      let!(:plan) { "professional" }

      it "ユーザー数が無制限であること" do
        create_list(:user, 5, :member, tenant: tenant)
        checker = described_class.new(tenant)
        expect(checker.check!(:users)).to be true
      end

      it "顧客数が無制限であること" do
        checker = described_class.new(tenant)
        expect(checker.check!(:customers)).to be true
      end
    end
  end

  describe "#can_add?" do
    let!(:plan) { "free" }

    it "制限内の場合trueを返すこと" do
      checker = described_class.new(tenant)
      expect(checker.can_add?(:customers)).to be true
    end

    it "制限超過の場合falseを返すこと" do
      checker = described_class.new(tenant)
      expect(checker.can_add?(:users)).to be false
    end
  end

  describe "#limit_for" do
    let!(:plan) { "standard" }

    it "プランの制限値を返すこと" do
      checker = described_class.new(tenant)
      expect(checker.limit_for(:users)).to eq(10)
      expect(checker.limit_for(:customers)).to eq(500)
    end

    it "存在しないリソースの場合エラーになること" do
      checker = described_class.new(tenant)
      expect { checker.limit_for(:unknown) }.to raise_error(ArgumentError)
    end
  end
end
