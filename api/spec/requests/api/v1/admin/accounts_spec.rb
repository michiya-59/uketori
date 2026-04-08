# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Admin::Accounts", type: :request do
  let!(:admin_tenant) { create(:tenant) }
  let!(:admin_user) { create(:user, tenant: admin_tenant, email: "admin@example.com", role: "owner", system_admin: true) }
  let!(:admin_token) { JwtService.encode(admin_user)[:access_token] }
  let!(:auth_headers) { { "Authorization" => "Bearer #{admin_token}" } }

  let!(:non_admin_user) { create(:user, tenant: admin_tenant, email: "member@example.com", role: "member") }
  let!(:non_admin_token) { JwtService.encode(non_admin_user)[:access_token] }
  let!(:non_admin_headers) { { "Authorization" => "Bearer #{non_admin_token}" } }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("ADMIN_EMAILS", "").and_return("admin@example.com")
  end

  describe ".index" do
    let!(:other_tenant) { create(:tenant, name: "テストテナント") }
    let!(:other_owner) { create(:user, tenant: other_tenant, role: "owner") }

    context "システム管理者の場合" do
      it "アカウント一覧が返されること" do
        get "/api/v1/admin/accounts", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["accounts"]).to be_an(Array)
        expect(json["accounts"].length).to be >= 2
        expect(json["meta"]).to include("current_page", "total_pages", "total_count")
      end
    end

    context "システム管理者でない場合" do
      it "403が返されること" do
        get "/api/v1/admin/accounts", headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "未認証の場合" do
      it "401が返されること" do
        get "/api/v1/admin/accounts"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe ".create" do
    let!(:valid_params) do
      {
        account: {
          tenant_name: "新規会社",
          industry_code: "it",
          name: "新規ユーザー",
          email: "newuser@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        }
      }
    end

    before do
      create(:industry_template, code: "it", name: "IT・通信") if IndustryTemplate.find_by(code: "it").nil?
    end

    context "システム管理者が有効なパラメータで発行する場合" do
      it "テナントとユーザーが作成されること" do
        expect {
          post "/api/v1/admin/accounts", params: valid_params, headers: auth_headers
        }.to change(Tenant, :count).by(1).and change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["account"]["tenant"]["name"]).to eq("新規会社")
        expect(json["account"]["user"]["email"]).to eq("newuser@example.com")
        expect(json["account"]["user"]["role"]).to eq("owner")
      end
    end

    context "会社名が空の場合" do
      it "エラーが返されること" do
        invalid_params = valid_params.deep_dup
        invalid_params[:account][:tenant_name] = ""

        post "/api/v1/admin/accounts", params: invalid_params, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json["error"]["code"]).to eq("registration_error")
      end
    end

    context "システム管理者でない場合" do
      it "403が返されること" do
        post "/api/v1/admin/accounts", params: valid_params, headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "メールアドレスが無効な場合" do
      it "エラーが返されること" do
        invalid_params = valid_params.deep_dup
        invalid_params[:account][:email] = "invalid-email"

        post "/api/v1/admin/accounts", params: invalid_params, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json["error"]["code"]).to eq("registration_error")
      end
    end
  end
end
