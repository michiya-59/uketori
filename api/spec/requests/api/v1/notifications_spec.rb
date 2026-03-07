# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Notifications", type: :request do
  let!(:tenant) { create(:tenant) }
  let!(:owner) { create(:user, :owner, tenant: tenant) }
  let!(:other_user) { create(:user, :member, tenant: tenant) }

  describe "GET /api/v1/notifications" do
    let!(:notification1) { create(:notification, tenant: tenant, user: owner) }
    let!(:notification2) { create(:notification, :read, tenant: tenant, user: owner) }
    let!(:notification3) { create(:notification, tenant: tenant, user: owner) }
    let!(:other_notification) { create(:notification, tenant: tenant, user: other_user) }

    context "認証済みユーザーの場合" do
      it "自分宛の通知一覧が返されること" do
        get "/api/v1/notifications", headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["notifications"].length).to eq(3)
        ids = body["notifications"].map { |n| n["id"] }
        expect(ids).not_to include(other_notification.id)
      end

      it "未読件数が返されること" do
        get "/api/v1/notifications", headers: auth_headers(owner)

        body = response.parsed_body
        expect(body["unread_count"]).to eq(2)
      end

      it "ページネーションメタが返されること" do
        get "/api/v1/notifications", headers: auth_headers(owner)

        body = response.parsed_body
        expect(body["meta"]).to be_present
        expect(body["meta"]["total_count"]).to eq(3)
      end

      it "通知のフィールドが正しく返されること" do
        get "/api/v1/notifications", headers: auth_headers(owner)

        body = response.parsed_body
        n = body["notifications"].first
        expect(n).to have_key("id")
        expect(n).to have_key("notification_type")
        expect(n).to have_key("title")
        expect(n).to have_key("body")
        expect(n).to have_key("is_read")
        expect(n).to have_key("created_at")
      end
    end

    context "認証なしの場合" do
      it "401エラーが返されること" do
        get "/api/v1/notifications"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/notifications/:id" do
    let!(:notification) { create(:notification, tenant: tenant, user: owner) }

    context "自分の通知を既読にする場合" do
      it "通知が既読になること" do
        patch "/api/v1/notifications/#{notification.id}", headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["notification"]["is_read"]).to be true
        expect(body["notification"]["read_at"]).to be_present
      end
    end

    context "他人の通知を既読にしようとする場合" do
      let!(:other_notification) { create(:notification, tenant: tenant, user: other_user) }

      it "404エラーが返されること" do
        patch "/api/v1/notifications/#{other_notification.id}", headers: auth_headers(owner)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "認証なしの場合" do
      it "401エラーが返されること" do
        patch "/api/v1/notifications/#{notification.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
