# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Auth::Passwords", type: :request do
  let!(:tenant) { create(:tenant) }
  let!(:user) { create(:user, :owner, tenant: tenant, password: "password123", password_confirmation: "password123") }

  describe "POST /api/v1/auth/password/reset" do
    context "登録済みメールアドレスの場合" do
      it "成功メッセージが返されパスワードリセットメールが送信されること" do
        expect {
          post "/api/v1/auth/password/reset",
               params: { auth: { email: user.email } },
               as: :json
        }.to have_enqueued_mail(AuthMailer, :password_reset).with(user, kind_of(String))

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["message"]).to include("パスワードリセット")
      end
    end

    context "存在しないメールアドレスの場合" do
      it "セキュリティのため同じ成功メッセージが返されること" do
        post "/api/v1/auth/password/reset",
             params: { auth: { email: "nonexistent@example.com" } },
             as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["message"]).to include("パスワードリセット")
      end

      it "メールが送信されないこと" do
        expect {
          post "/api/v1/auth/password/reset",
               params: { auth: { email: "nonexistent@example.com" } },
               as: :json
        }.not_to have_enqueued_mail(AuthMailer, :password_reset)
      end
    end
  end

  describe "PATCH /api/v1/auth/password/update" do
    context "有効なリセットトークンの場合" do
      let!(:reset_token) { user.password_reset_token }

      it "パスワードが更新され成功メッセージが返されること" do
        patch "/api/v1/auth/password/update",
              params: {
                auth: {
                  token: reset_token,
                  password: "newpassword123",
                  password_confirmation: "newpassword123"
                }
              },
              as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["message"]).to include("パスワードを更新")

        # 新しいパスワードでサインインできることを確認
        post "/api/v1/auth/sign_in",
             params: { auth: { email: user.email, password: "newpassword123" } },
             as: :json
        expect(response).to have_http_status(:ok)
      end

      it "既存のJWTが無効化されること" do
        old_jti = user.jti

        patch "/api/v1/auth/password/update",
              params: {
                auth: {
                  token: reset_token,
                  password: "newpassword123",
                  password_confirmation: "newpassword123"
                }
              },
              as: :json

        expect(user.reload.jti).not_to eq(old_jti)
      end
    end

    context "無効なリセットトークンの場合" do
      it "422エラーが返されること" do
        patch "/api/v1/auth/password/update",
              params: {
                auth: {
                  token: "invalid_token",
                  password: "newpassword123",
                  password_confirmation: "newpassword123"
                }
              },
              as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        body = response.parsed_body
        expect(body["error"]["code"]).to eq("password_reset_error")
      end
    end

    context "パスワードが不一致の場合" do
      let!(:reset_token) { user.password_reset_token }

      it "422エラーが返されること" do
        patch "/api/v1/auth/password/update",
              params: {
                auth: {
                  token: reset_token,
                  password: "newpassword123",
                  password_confirmation: "different"
                }
              },
              as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
