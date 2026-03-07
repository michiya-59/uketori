# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Auth::SignUps", type: :request do
  let!(:industry_template) { create(:industry_template, code: "general") }

  describe "POST /api/v1/auth/sign_up" do
    let!(:valid_params) do
      {
        auth: {
          tenant_name: "新規テスト会社",
          industry_code: "general",
          name: "新規ユーザー",
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    context "有効なパラメータの場合" do
      it "テナントとユーザーが作成されトークンが返されること" do
        expect {
          post "/api/v1/auth/sign_up", params: valid_params, as: :json
        }.to change(Tenant, :count).by(1).and change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["user"]["name"]).to eq("新規ユーザー")
        expect(body["user"]["email"]).to eq("newuser@example.com")
        expect(body["user"]["role"]).to eq("owner")
        expect(body["tenant"]["name"]).to eq("新規テスト会社")
        expect(body["tokens"]["access_token"]).to be_present
        expect(body["tokens"]["refresh_token"]).to be_present
      end
    end

    context "メールアドレスが空の場合" do
      it "422エラーが返されること" do
        invalid_params = valid_params.deep_dup
        invalid_params[:auth][:email] = ""
        post "/api/v1/auth/sign_up", params: invalid_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        body = response.parsed_body
        expect(body["error"]["code"]).to eq("registration_error")
      end
    end

    context "パスワードが不一致の場合" do
      it "422エラーが返されること" do
        invalid_params = valid_params.deep_dup
        invalid_params[:auth][:password_confirmation] = "different"
        post "/api/v1/auth/sign_up", params: invalid_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
