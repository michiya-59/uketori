# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tenant, type: :model do
  describe "バリデーション" do
    let!(:tenant) { create(:tenant) }

    context "有効な属性の場合" do
      it "バリデーションが通ること" do
        expect(tenant).to be_valid
      end
    end

    context "nameが空の場合" do
      it "バリデーションエラーになること" do
        tenant.name = nil
        expect(tenant).not_to be_valid
        expect(tenant.errors[:name]).to be_present
      end
    end

    context "nameが255文字を超える場合" do
      it "バリデーションエラーになること" do
        tenant.name = "あ" * 256
        expect(tenant).not_to be_valid
      end
    end

    context "planが無効な値の場合" do
      it "バリデーションエラーになること" do
        tenant.plan = "invalid_plan"
        expect(tenant).not_to be_valid
      end
    end

    context "industry_typeが空の場合" do
      it "バリデーションエラーになること" do
        tenant.industry_type = nil
        expect(tenant).not_to be_valid
      end
    end

    context "default_tax_rateが負の値の場合" do
      it "バリデーションエラーになること" do
        tenant.default_tax_rate = -1
        expect(tenant).not_to be_valid
      end
    end

    context "fiscal_year_start_monthが範囲外の場合" do
      it "0の場合バリデーションエラーになること" do
        tenant.fiscal_year_start_month = 0
        expect(tenant).not_to be_valid
      end

      it "13の場合バリデーションエラーになること" do
        tenant.fiscal_year_start_month = 13
        expect(tenant).not_to be_valid
      end
    end

    context "default_payment_terms_daysが0以下の場合" do
      it "バリデーションエラーになること" do
        tenant.default_payment_terms_days = 0
        expect(tenant).not_to be_valid
      end
    end
  end

  describe "アソシエーション" do
    let!(:tenant) { create(:tenant) }
    let!(:user) { create(:user, tenant: tenant) }

    context "ユーザーとの関連" do
      it "usersを持つこと" do
        expect(tenant.users).to include(user)
      end
    end
  end
end
