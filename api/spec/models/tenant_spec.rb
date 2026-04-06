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

  describe "#ip_allowed?" do
    let!(:tenant) { create(:tenant, ip_restriction_enabled: false, allowed_ip_addresses: ["192.168.1.0/24", "10.0.0.1"]) }

    context "IP制限が無効の場合" do
      it "どのIPでもtrueを返すこと" do
        expect(tenant.ip_allowed?("203.0.113.50")).to be true
      end
    end

    context "IP制限が有効の場合" do
      before { tenant.update!(ip_restriction_enabled: true) }

      it "許可リストに含まれるIPはtrueを返すこと" do
        expect(tenant.ip_allowed?("10.0.0.1")).to be true
      end

      it "CIDR範囲内のIPはtrueを返すこと" do
        expect(tenant.ip_allowed?("192.168.1.100")).to be true
      end

      it "許可リストに含まれないIPはfalseを返すこと" do
        expect(tenant.ip_allowed?("203.0.113.50")).to be false
      end

      it "CIDR範囲外のIPはfalseを返すこと" do
        expect(tenant.ip_allowed?("192.168.2.1")).to be false
      end

      it "不正なIPアドレスはfalseを返すこと" do
        expect(tenant.ip_allowed?("invalid")).to be false
      end
    end

    context "許可リストが空の場合" do
      let!(:tenant) { create(:tenant, ip_restriction_enabled: true, allowed_ip_addresses: []) }

      it "trueを返すこと" do
        expect(tenant.ip_allowed?("203.0.113.50")).to be true
      end
    end
  end

  describe "allowed_ip_addressesバリデーション" do
    let!(:tenant) { create(:tenant) }

    context "有効なIPアドレスの場合" do
      it "バリデーションが通ること" do
        tenant.allowed_ip_addresses = ["192.168.1.1", "10.0.0.0/8"]
        expect(tenant).to be_valid
      end
    end

    context "無効なIPアドレスの場合" do
      it "バリデーションエラーになること" do
        tenant.allowed_ip_addresses = ["not_an_ip"]
        expect(tenant).not_to be_valid
        expect(tenant.errors[:allowed_ip_addresses]).to be_present
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
