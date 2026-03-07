# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Auth::Sessions", type: :request do
  let!(:tenant) { create(:tenant) }
  let!(:user) { create(:user, :owner, tenant: tenant, password: "password123", password_confirmation: "password123") }

  describe "POST /api/v1/auth/sign_in" do
    context "正しい認証情報の場合" do
      it "ユーザー情報とトークンが返されること" do
        post "/api/v1/auth/sign_in", params: { auth: { email: user.email, password: "password123" } }, as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["user"]["id"]).to eq(user.uuid)
        expect(body["user"]["name"]).to eq(user.name)
        expect(body["tokens"]["access_token"]).to be_present
      end

      it "サインイン回数が増加すること" do
        expect {
          post "/api/v1/auth/sign_in", params: { auth: { email: user.email, password: "password123" } }, as: :json
        }.to change { user.reload.sign_in_count }.by(1)
      end
    end

    context "パスワードが間違っている場合" do
      it "401エラーが返されること" do
        post "/api/v1/auth/sign_in", params: { auth: { email: user.email, password: "wrong" } }, as: :json

        expect(response).to have_http_status(:unauthorized)
        body = response.parsed_body
        expect(body["error"]["code"]).to eq("authentication_error")
      end
    end

    context "存在しないメールアドレスの場合" do
      it "401エラーが返されること" do
        post "/api/v1/auth/sign_in", params: { auth: { email: "nonexistent@example.com", password: "password123" } }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/auth/sign_out" do
    context "認証済みの場合" do
      it "204が返されjtiが更新されること" do
        old_jti = user.jti
        delete "/api/v1/auth/sign_out", headers: auth_headers(user)

        expect(response).to have_http_status(:no_content)
        expect(user.reload.jti).not_to eq(old_jti)
      end
    end

    context "未認証の場合" do
      it "401エラーが返されること" do
        delete "/api/v1/auth/sign_out"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/auth/refresh" do
    let!(:tokens) { JwtService.encode(user) }

    context "有効なリフレッシュトークンの場合" do
      it "新しいトークンペアが返されること" do
        post "/api/v1/auth/refresh", params: { refresh_token: tokens[:refresh_token] }, as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["tokens"]["access_token"]).to be_present
        expect(body["tokens"]["refresh_token"]).to be_present
        expect(body["tokens"]["expires_in"]).to eq(900)
      end
    end

    context "無効なリフレッシュトークンの場合" do
      it "401エラーが返されること" do
        post "/api/v1/auth/refresh", params: { refresh_token: "invalid" }, as: :json

        expect(response).to have_http_status(:unauthorized)
        body = response.parsed_body
        expect(body["error"]["code"]).to eq("invalid_refresh_token")
      end
    end
  end
end
