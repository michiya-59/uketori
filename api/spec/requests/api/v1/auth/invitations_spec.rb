# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Auth::Invitations", type: :request do
  let!(:tenant) { create(:tenant) }
  let!(:admin_user) { create(:user, :admin, tenant: tenant) }

  describe "POST /api/v1/auth/invitation/accept" do
    let!(:invited_user) do
      AuthService.invite_user(
        admin_user,
        { email: "invited@example.com", name: "招待ユーザー", role: "member" }
      )
    end

    context "有効な招待トークンの場合" do
      it "パスワードが設定されユーザー情報とトークンが返されること" do
        post "/api/v1/auth/invitation/accept",
             params: {
               auth: {
                 token: invited_user.invitation_token,
                 password: "Newpassword123!",
                 password_confirmation: "Newpassword123!"
               }
             },
             as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["user"]["email"]).to eq("invited@example.com")
        expect(body["user"]["name"]).to eq("招待ユーザー")
        expect(body["user"]["role"]).to eq("member")
        expect(body["tokens"]["access_token"]).to be_present
        expect(body["tokens"]["refresh_token"]).to be_present
      end

      it "招待トークンがクリアされ招待受諾日時が設定されること" do
        post "/api/v1/auth/invitation/accept",
             params: {
               auth: {
                 token: invited_user.invitation_token,
                 password: "Newpassword123!",
                 password_confirmation: "Newpassword123!"
               }
             },
             as: :json

        invited_user.reload
        expect(invited_user.invitation_token).to be_nil
        expect(invited_user.invitation_accepted_at).to be_present
      end

      it "設定したパスワードでサインインできること" do
        token = invited_user.invitation_token
        post "/api/v1/auth/invitation/accept",
             params: {
               auth: {
                 token: token,
                 password: "Newpassword123!",
                 password_confirmation: "Newpassword123!"
               }
             },
             as: :json

        post "/api/v1/auth/sign_in",
             params: { auth: { email: "invited@example.com", password: "Newpassword123!" } },
             as: :json
        expect(response).to have_http_status(:ok)
      end
    end

    context "無効な招待トークンの場合" do
      it "422エラーが返されること" do
        post "/api/v1/auth/invitation/accept",
             params: {
               auth: {
                 token: "invalid_token",
                 password: "Newpassword123!",
                 password_confirmation: "Newpassword123!"
               }
             },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        body = response.parsed_body
        expect(body["error"]["code"]).to eq("invitation_error")
      end
    end

    context "パスワードが不一致の場合" do
      it "422エラーが返されること" do
        post "/api/v1/auth/invitation/accept",
             params: {
               auth: {
                 token: invited_user.invitation_token,
                 password: "Newpassword123!",
                 password_confirmation: "different"
               }
             },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
