# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Auth::SignUps", type: :request do
  before do
    create(:industry_template, code: "general", name: "汎用") if IndustryTemplate.find_by(code: "general").nil?
  end

  describe "POST /api/v1/auth/sign_up" do
    let(:valid_params) do
      {
        auth: {
          tenant_name: "新規会社",
          industry_code: "general",
          name: "新規オーナー",
          email: "signup@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        }
      }
    end

    it "テナントとオーナーを作成してトークンを返すこと" do
      expect {
        post "/api/v1/auth/sign_up", params: valid_params, as: :json
      }.to change(Tenant, :count).by(1).and change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["user"]["role"]).to eq("owner")
      expect(body["tenant"]["name"]).to eq("新規会社")
      expect(body["tokens"]["access_token"]).to be_present
    end

    it "無効な業種コードでは422が返ること" do
      post "/api/v1/auth/sign_up",
           params: valid_params.deep_merge(auth: { industry_code: "missing" }),
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig("error", "code")).to eq("registration_error")
    end

    it "弱いパスワードでは422が返ること" do
      post "/api/v1/auth/sign_up",
           params: valid_params.deep_merge(auth: { password: "password123", password_confirmation: "password123" }),
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig("error", "code")).to eq("registration_error")
    end
  end
end
