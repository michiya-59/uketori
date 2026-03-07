# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::IndustryTemplates", type: :request do
  let!(:general) { create(:industry_template, code: "general", name: "一般", sort_order: 0) }
  let!(:construction) { create(:industry_template, code: "construction", name: "建設業", sort_order: 1) }
  let!(:it_template) { create(:industry_template, code: "it_web", name: "IT・Web制作業", sort_order: 2) }
  let!(:inactive_template) { create(:industry_template, code: "inactive", name: "非アクティブ", sort_order: 99, is_active: false) }

  describe "GET /api/v1/industry_templates" do
    context "一覧を取得する場合" do
      it "有効なテンプレートのみが返されること" do
        get "/api/v1/industry_templates"

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        codes = body["industry_templates"].map { |t| t["code"] }
        expect(codes).to include("general", "construction", "it_web")
        expect(codes).not_to include("inactive")
      end

      it "sort_order順にソートされること" do
        get "/api/v1/industry_templates"

        body = response.parsed_body
        templates = body["industry_templates"]
        orders = templates.map { |t| t["sort_order"] }
        expect(orders).to eq(orders.sort)
      end

      it "code, name, sort_orderが含まれること" do
        get "/api/v1/industry_templates"

        body = response.parsed_body
        template = body["industry_templates"].find { |t| t["code"] == "general" }
        expect(template).to include("code" => "general", "name" => "一般", "sort_order" => 0)
      end
    end

    context "認証なしの場合" do
      it "認証不要で取得できること" do
        get "/api/v1/industry_templates"
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /api/v1/industry_templates/:id" do
    context "存在するコードを指定した場合" do
      it "テンプレート詳細が返されること" do
        get "/api/v1/industry_templates/#{general.code}"

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        detail = body["industry_template"]
        expect(detail["code"]).to eq("general")
        expect(detail["name"]).to eq("一般")
        expect(detail).to have_key("labels")
        expect(detail).to have_key("default_products")
        expect(detail).to have_key("default_statuses")
        expect(detail).to have_key("tax_settings")
      end
    end

    context "存在しないコードを指定した場合" do
      it "404エラーが返されること" do
        get "/api/v1/industry_templates/nonexistent"
        expect(response).to have_http_status(:not_found)
      end
    end

    context "認証なしの場合" do
      it "認証不要で取得できること" do
        get "/api/v1/industry_templates/#{general.code}"
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
