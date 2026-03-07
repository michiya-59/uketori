# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Products", type: :request do
  let!(:tenant) { create(:tenant) }
  let!(:owner) { create(:user, :owner, tenant: tenant) }
  let!(:accountant) { create(:user, :accountant, tenant: tenant) }
  let!(:sales) { create(:user, :sales, tenant: tenant) }
  let!(:product) { create(:product, tenant: tenant, name: "テスト品目", sort_order: 1) }

  describe "GET /api/v1/products" do
    let!(:product2) { create(:product, tenant: tenant, name: "品目2", sort_order: 2) }
    let!(:inactive) { create(:product, :inactive, tenant: tenant, name: "無効品目", sort_order: 3) }

    context "認証済みユーザーの場合" do
      it "有効な品目一覧がソート順に返されること" do
        get "/api/v1/products", headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["products"].length).to eq(2)
        expect(body["products"][0]["name"]).to eq("テスト品目")
      end
    end

    context "無効品目も含める場合" do
      it "全品目が返されること" do
        get "/api/v1/products", params: { filter: { active: "false" } }, headers: auth_headers(owner)

        body = response.parsed_body
        expect(body["products"].length).to eq(3)
      end
    end
  end

  describe "POST /api/v1/products" do
    let!(:valid_params) do
      { product: { name: "新品目", unit: "個", unit_price: 5000, tax_rate: 10, tax_rate_type: "standard" } }
    end

    context "accountant以上のロールの場合" do
      it "品目が作成されること" do
        expect {
          post "/api/v1/products", params: valid_params, headers: auth_headers(accountant), as: :json
        }.to change(Product, :count).by(1)

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["product"]["name"]).to eq("新品目")
      end
    end

    context "salesロールの場合" do
      it "403エラーが返されること" do
        post "/api/v1/products", params: valid_params, headers: auth_headers(sales), as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /api/v1/products/:id" do
    it "品目情報が更新されること" do
      patch "/api/v1/products/#{product.id}",
            params: { product: { name: "更新品目", unit_price: 8000 } },
            headers: auth_headers(accountant), as: :json

      expect(response).to have_http_status(:ok)
      expect(product.reload.name).to eq("更新品目")
      expect(product.unit_price).to eq(8000)
    end
  end

  describe "DELETE /api/v1/products/:id" do
    context "admin以上のロールの場合" do
      it "品目が削除されること" do
        expect {
          delete "/api/v1/products/#{product.id}", headers: auth_headers(owner)
        }.to change(Product, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "accountantロールの場合" do
      it "403エラーが返されること" do
        delete "/api/v1/products/#{product.id}", headers: auth_headers(accountant)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
