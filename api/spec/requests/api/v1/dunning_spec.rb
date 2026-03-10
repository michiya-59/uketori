# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Dunning", type: :request do
  let!(:tenant) { create(:tenant, plan: "starter") }
  let!(:owner) { create(:user, :owner, tenant: tenant) }
  let!(:accountant) { create(:user, :accountant, tenant: tenant) }
  let!(:member) { create(:user, :member, tenant: tenant) }

  describe "GET /api/v1/dunning/rules" do
    let!(:rule1) { create(:dunning_rule, tenant: tenant, sort_order: 0) }
    let!(:rule2) { create(:dunning_rule, tenant: tenant, sort_order: 1) }

    it "ルール一覧が返されること" do
      get "/api/v1/dunning/rules", headers: auth_headers(member)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["rules"].length).to eq(2)
    end
  end

  describe "POST /api/v1/dunning/rules" do
    let!(:valid_params) do
      {
        rule: {
          name: "テスト督促ルール",
          trigger_days_after_due: 7,
          action_type: "email",
          email_template_subject: "お支払いのお願い",
          email_template_body: "テスト本文",
          send_to: "billing_contact",
          max_dunning_count: 3,
          interval_days: 7
        }
      }
    end

    context "accountant以上のロールの場合" do
      it "ルールが作成されること" do
        expect {
          post "/api/v1/dunning/rules", params: valid_params, headers: auth_headers(accountant), as: :json
        }.to change(DunningRule, :count).by(1)

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["rule"]["name"]).to eq("テスト督促ルール")
      end
    end

    context "memberロールの場合" do
      it "403エラーが返されること" do
        post "/api/v1/dunning/rules", params: valid_params, headers: auth_headers(member), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /api/v1/dunning/rules/:id" do
    let!(:rule) { create(:dunning_rule, tenant: tenant) }

    context "accountant以上のロールの場合" do
      it "ルールが更新されること" do
        patch "/api/v1/dunning/rules/#{rule.id}",
              params: { rule: { name: "更新後ルール名" } },
              headers: auth_headers(accountant), as: :json

        expect(response).to have_http_status(:ok)
        expect(rule.reload.name).to eq("更新後ルール名")
      end
    end
  end

  describe "DELETE /api/v1/dunning/rules/:id" do
    let!(:rule) { create(:dunning_rule, tenant: tenant) }

    context "admin以上のロールの場合" do
      it "ルールが削除されること" do
        expect {
          delete "/api/v1/dunning/rules/#{rule.id}", headers: auth_headers(owner)
        }.to change(DunningRule, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "accountantロールの場合" do
      it "403エラーが返されること" do
        delete "/api/v1/dunning/rules/#{rule.id}", headers: auth_headers(accountant)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /api/v1/dunning/logs" do
    let!(:customer) { create(:customer, tenant: tenant) }
    let!(:invoice) do
      create(:document, :invoice, tenant: tenant, customer: customer, created_by_user: owner)
    end
    let!(:rule) { create(:dunning_rule, tenant: tenant) }
    let!(:log) do
      create(:dunning_log, tenant: tenant, document: invoice, dunning_rule: rule, customer: customer)
    end

    it "督促ログ一覧が返されること" do
      get "/api/v1/dunning/logs", headers: auth_headers(member)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["logs"].length).to eq(1)
      expect(body["logs"][0]["status"]).to eq("sent")
    end
  end

  describe "POST /api/v1/dunning/execute" do
    context "accountant以上のロールの場合" do
      it "督促実行結果が返されること" do
        post "/api/v1/dunning/execute", headers: auth_headers(accountant)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body).to have_key("sent")
        expect(body).to have_key("skipped")
        expect(body).to have_key("failed")
      end
    end

    context "memberロールの場合" do
      it "403エラーが返されること" do
        post "/api/v1/dunning/execute", headers: auth_headers(member)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
