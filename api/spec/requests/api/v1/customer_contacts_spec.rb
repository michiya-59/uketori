# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::CustomerContacts", type: :request do
  let!(:tenant) { create(:tenant) }
  let!(:owner) { create(:user, :owner, tenant: tenant) }
  let!(:member) { create(:user, :member, tenant: tenant) }
  let!(:customer) { create(:customer, tenant: tenant) }
  let!(:contact) { create(:customer_contact, customer: customer, name: "田中太郎") }

  describe "GET /api/v1/customers/:customer_id/contacts" do
    it "担当者一覧が返されること" do
      get "/api/v1/customers/#{customer.uuid}/contacts", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["contacts"].length).to eq(1)
      expect(body["contacts"][0]["name"]).to eq("田中太郎")
    end
  end

  describe "POST /api/v1/customers/:customer_id/contacts" do
    let!(:valid_params) do
      { contact: { name: "山田花子", email: "hanako@example.com", department: "経理部" } }
    end

    context "sales以上のロールの場合" do
      it "担当者が作成されること" do
        expect {
          post "/api/v1/customers/#{customer.uuid}/contacts",
               params: valid_params, headers: auth_headers(owner), as: :json
        }.to change(CustomerContact, :count).by(1)

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["contact"]["name"]).to eq("山田花子")
      end
    end

    context "memberロールの場合" do
      it "403エラーが返されること" do
        post "/api/v1/customers/#{customer.uuid}/contacts",
             params: valid_params, headers: auth_headers(member), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /api/v1/customers/:customer_id/contacts/:id" do
    it "担当者情報が更新されること" do
      patch "/api/v1/customers/#{customer.uuid}/contacts/#{contact.id}",
            params: { contact: { name: "田中一郎", is_primary: true } },
            headers: auth_headers(owner), as: :json

      expect(response).to have_http_status(:ok)
      expect(contact.reload.name).to eq("田中一郎")
      expect(contact.is_primary).to be true
    end
  end

  describe "DELETE /api/v1/customers/:customer_id/contacts/:id" do
    it "担当者が削除されること" do
      expect {
        delete "/api/v1/customers/#{customer.uuid}/contacts/#{contact.id}",
               headers: auth_headers(owner)
      }.to change(CustomerContact, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
