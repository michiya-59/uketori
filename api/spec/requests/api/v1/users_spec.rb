# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Users", type: :request do
  let!(:tenant) { create(:tenant, plan: "standard") }
  let!(:owner) { create(:user, :owner, tenant: tenant) }
  let!(:admin) { create(:user, :admin, tenant: tenant) }
  let!(:member) { create(:user, :member, tenant: tenant) }

  describe "GET /api/v1/users" do
    context "認証済みユーザーの場合" do
      it "同一テナントのユーザー一覧が返されること" do
        get "/api/v1/users", headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["users"].length).to eq(3)
        expect(body["meta"]["total_count"]).to eq(3)
      end
    end

    context "他テナントのユーザーの場合" do
      let!(:other_tenant) { create(:tenant, name: "他社") }
      let!(:other_user) { create(:user, tenant: other_tenant) }

      it "他テナントのユーザーが含まれないこと" do
        get "/api/v1/users", headers: auth_headers(owner)

        body = response.parsed_body
        user_ids = body["users"].map { |u| u["id"] }
        expect(user_ids).not_to include(other_user.uuid)
      end
    end

    context "未認証の場合" do
      it "401エラーが返されること" do
        get "/api/v1/users"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/users/:id" do
    context "認証済みユーザーの場合" do
      it "ユーザー詳細が返されること" do
        get "/api/v1/users/#{member.uuid}", headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["user"]["id"]).to eq(member.uuid)
        expect(body["user"]["name"]).to eq(member.name)
        expect(body["user"]["sign_in_count"]).to be_present
      end
    end
  end

  describe "PATCH /api/v1/users/:id" do
    context "admin以上が更新する場合" do
      it "ユーザー情報が更新されること" do
        patch "/api/v1/users/#{member.uuid}",
              params: { user: { name: "更新された名前" } },
              headers: auth_headers(admin),
              as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["user"]["name"]).to eq("更新された名前")
      end
    end

    context "memberが更新しようとした場合" do
      it "403エラーが返されること" do
        patch "/api/v1/users/#{admin.uuid}",
              params: { user: { name: "ハッカー" } },
              headers: auth_headers(member),
              as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "DELETE /api/v1/users/:id" do
    context "admin以上がmemberを削除する場合" do
      it "論理削除されること" do
        delete "/api/v1/users/#{member.uuid}", headers: auth_headers(admin)

        expect(response).to have_http_status(:no_content)
        expect(member.reload.deleted_at).to be_present
      end
    end

    context "adminが自分を削除しようとした場合" do
      it "403エラーが返されること" do
        delete "/api/v1/users/#{admin.uuid}", headers: auth_headers(admin)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "adminがownerを削除しようとした場合" do
      it "403エラーが返されること" do
        delete "/api/v1/users/#{owner.uuid}", headers: auth_headers(admin)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "POST /api/v1/users/invite" do
    context "admin以上が招待する場合" do
      it "招待ユーザーが作成されること" do
        expect {
          post "/api/v1/users/invite",
               params: { user: { email: "invite@example.com", name: "招待者", role: "sales" } },
               headers: auth_headers(admin),
               as: :json
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["user"]["email"]).to eq("invite@example.com")
        expect(body["user"]["role"]).to eq("sales")
      end
    end

    context "memberが招待しようとした場合" do
      it "403エラーが返されること" do
        post "/api/v1/users/invite",
             params: { user: { email: "invite@example.com", name: "招待者", role: "member" } },
             headers: auth_headers(member),
             as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
