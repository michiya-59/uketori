# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Tenants", type: :request do
  let!(:tenant) { create(:tenant, :with_full_info) }
  let!(:owner) { create(:user, :owner, tenant: tenant) }
  let!(:admin) { create(:user, :admin, tenant: tenant) }
  let!(:member) { create(:user, :member, tenant: tenant) }

  describe "GET /api/v1/tenant" do
    context "認証済みユーザーの場合" do
      it "テナント基本情報が返されること" do
        get "/api/v1/tenant", headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["tenant"]["id"]).to eq(tenant.uuid)
        expect(body["tenant"]["name"]).to eq(tenant.name)
        expect(body["tenant"]["plan"]).to eq(tenant.plan)
      end

      it "住所情報が返されること" do
        get "/api/v1/tenant", headers: auth_headers(owner)

        body = response.parsed_body
        t = body["tenant"]
        expect(t["postal_code"]).to eq("100-0001")
        expect(t["prefecture"]).to eq("東京都")
        expect(t["city"]).to eq("千代田区")
        expect(t["address_line1"]).to eq("丸の内1-1-1")
        expect(t["address_line2"]).to eq("サンプルビル3F")
      end

      it "連絡先情報が返されること" do
        get "/api/v1/tenant", headers: auth_headers(owner)

        body = response.parsed_body
        t = body["tenant"]
        expect(t["phone"]).to eq("03-1234-5678")
        expect(t["fax"]).to eq("03-1234-5679")
        expect(t["email"]).to eq("info@test.co.jp")
        expect(t["website"]).to eq("https://test.co.jp")
      end

      it "インボイス情報が返されること" do
        get "/api/v1/tenant", headers: auth_headers(owner)

        body = response.parsed_body
        t = body["tenant"]
        expect(t["invoice_registration_number"]).to eq("T1234567890123")
      end

      it "振込先情報が返されること" do
        get "/api/v1/tenant", headers: auth_headers(owner)

        body = response.parsed_body
        t = body["tenant"]
        expect(t["bank_name"]).to eq("三菱UFJ銀行")
        expect(t["bank_branch_name"]).to eq("丸の内支店")
        expect(t["bank_account_type"]).to eq("ordinary")
        expect(t["bank_account_number"]).to eq("1234567")
        expect(t["bank_account_holder"]).to eq("テスト（カ")
      end

      it "帳票設定が返されること" do
        get "/api/v1/tenant", headers: auth_headers(owner)

        body = response.parsed_body
        t = body["tenant"]
        expect(t["default_tax_rate"]).to eq("10.0")
        expect(t["default_payment_terms_days"]).to eq(30)
        expect(t["fiscal_year_start_month"]).to eq(4)
      end

      it "memberでも参照できること" do
        get "/api/v1/tenant", headers: auth_headers(member)
        expect(response).to have_http_status(:ok)
      end
    end

    context "未認証の場合" do
      it "401エラーが返されること" do
        get "/api/v1/tenant"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/tenant" do
    context "ownerが基本情報を更新する場合" do
      it "会社名が更新されること" do
        patch "/api/v1/tenant",
              params: { tenant: { name: "更新テスト会社", name_kana: "コウシンテストカイシャ" } },
              headers: auth_headers(owner),
              as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["tenant"]["name"]).to eq("更新テスト会社")
        expect(body["tenant"]["name_kana"]).to eq("コウシンテストカイシャ")
      end
    end

    context "ownerが住所を更新する場合" do
      it "住所情報が更新されること" do
        patch "/api/v1/tenant",
              params: { tenant: {
                postal_code: "150-0002",
                prefecture: "東京都",
                city: "渋谷区",
                address_line1: "渋谷2-2-2",
                address_line2: "渋谷ビル5F"
              } },
              headers: auth_headers(owner),
              as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["tenant"]["postal_code"]).to eq("150-0002")
        expect(body["tenant"]["city"]).to eq("渋谷区")
        expect(body["tenant"]["address_line1"]).to eq("渋谷2-2-2")
        expect(body["tenant"]["address_line2"]).to eq("渋谷ビル5F")
      end
    end

    context "ownerが連絡先を更新する場合" do
      it "連絡先情報が更新されること" do
        patch "/api/v1/tenant",
              params: { tenant: {
                phone: "06-9876-5432",
                fax: "06-9876-5433",
                email: "new@test.co.jp",
                website: "https://new-test.co.jp"
              } },
              headers: auth_headers(owner),
              as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["tenant"]["phone"]).to eq("06-9876-5432")
        expect(body["tenant"]["fax"]).to eq("06-9876-5433")
        expect(body["tenant"]["email"]).to eq("new@test.co.jp")
        expect(body["tenant"]["website"]).to eq("https://new-test.co.jp")
      end
    end

    context "ownerがインボイス番号を更新する場合" do
      it "インボイス登録番号が更新されること" do
        patch "/api/v1/tenant",
              params: { tenant: { invoice_registration_number: "T9999999999999" } },
              headers: auth_headers(owner),
              as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["tenant"]["invoice_registration_number"]).to eq("T9999999999999")
      end
    end

    context "ownerが振込先を更新する場合" do
      it "振込先情報が更新されること" do
        patch "/api/v1/tenant",
              params: { tenant: {
                bank_name: "みずほ銀行",
                bank_branch_name: "渋谷支店",
                bank_account_type: "checking",
                bank_account_number: "7654321",
                bank_account_holder: "コウシン（カ"
              } },
              headers: auth_headers(owner),
              as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["tenant"]["bank_name"]).to eq("みずほ銀行")
        expect(body["tenant"]["bank_branch_name"]).to eq("渋谷支店")
        expect(body["tenant"]["bank_account_type"]).to eq("checking")
        expect(body["tenant"]["bank_account_number"]).to eq("7654321")
        expect(body["tenant"]["bank_account_holder"]).to eq("コウシン（カ")
      end
    end

    context "ownerが帳票設定を更新する場合" do
      it "帳票設定が更新されること" do
        patch "/api/v1/tenant",
              params: { tenant: {
                default_tax_rate: 8.0,
                default_payment_terms_days: 60,
                fiscal_year_start_month: 1
              } },
              headers: auth_headers(owner),
              as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["tenant"]["default_tax_rate"]).to eq("8.0")
        expect(body["tenant"]["default_payment_terms_days"]).to eq(60)
        expect(body["tenant"]["fiscal_year_start_month"]).to eq(1)
      end
    end

    context "ownerが督促設定を更新する場合" do
      it "督促設定が更新されること" do
        patch "/api/v1/tenant",
              params: { tenant: { dunning_enabled: true } },
              headers: auth_headers(owner),
              as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["tenant"]["dunning_enabled"]).to be true
      end
    end

    context "adminが更新する場合" do
      it "テナント設定が更新されること" do
        patch "/api/v1/tenant",
              params: { tenant: { name: "Admin更新会社" } },
              headers: auth_headers(admin),
              as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["tenant"]["name"]).to eq("Admin更新会社")
      end
    end

    context "memberが更新しようとした場合" do
      it "403エラーが返されること" do
        patch "/api/v1/tenant",
              params: { tenant: { name: "ハッカー会社" } },
              headers: auth_headers(member),
              as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "未認証の場合" do
      it "401エラーが返されること" do
        patch "/api/v1/tenant",
              params: { tenant: { name: "不正更新" } },
              as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
