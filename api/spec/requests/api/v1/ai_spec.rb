# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::AiController", type: :request do
  let!(:tenant) { create(:tenant, plan: "standard") }
  let!(:user) { create(:user, :owner, tenant: tenant) }
  let!(:customer) { create(:customer, tenant: tenant, credit_score: 70) }

  describe "POST /api/v1/ai/estimate_suggestion" do
    context "認証済みユーザーの場合" do
      it "見積提案を返すこと" do
        post "/api/v1/ai/estimate_suggestion",
             params: { customer_id: customer.uuid, project_description: "Webサイト制作" },
             headers: auth_headers(user), as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body).to have_key("suggestions")
        expect(body).to have_key("confidence")
      end

      context "過去見積がある場合" do
        let!(:past_estimate) do
          doc = create(:document, :estimate, tenant: tenant, customer: customer,
                       created_by_user: user, title: "Webサイト制作")
          create(:document_item, document: doc, name: "デザイン制作", quantity: 1,
                 unit: "式", unit_price: 500_000)
          doc
        end

        it "過去データに基づく提案を返すこと" do
          post "/api/v1/ai/estimate_suggestion",
               params: { customer_id: customer.uuid, project_description: "Webサイト制作", hints: ["レスポンシブ"] },
               headers: auth_headers(user), as: :json

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context "freeプランの場合" do
      let!(:free_tenant) { create(:tenant, plan: "free") }
      let!(:free_user) { create(:user, :owner, tenant: free_tenant) }
      let!(:free_customer) { create(:customer, tenant: free_tenant) }

      it "プラン制限エラーになること" do
        post "/api/v1/ai/estimate_suggestion",
             params: { customer_id: free_customer.uuid },
             headers: auth_headers(free_user), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["error"]["code"]).to eq("plan_limit_exceeded")
      end
    end

    context "未認証の場合" do
      it "401エラーを返すこと" do
        post "/api/v1/ai/estimate_suggestion",
             params: { customer_id: customer.uuid }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/ai/revenue_forecast" do
    context "認証済みユーザーの場合" do
      let!(:invoices) do
        (1..3).map do |i|
          create(:document, :invoice,
                 tenant: tenant, customer: customer, created_by_user: user,
                 issue_date: i.months.ago.to_date,
                 total_amount: 1_000_000, paid_amount: 1_000_000,
                 status: "sent", payment_status: "paid")
        end
      end

      it "売上予測を返すこと" do
        post "/api/v1/ai/revenue_forecast",
             params: { months: 3 },
             headers: auth_headers(user), as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body).to have_key("historical")
        expect(body).to have_key("forecast")
        expect(body).to have_key("commentary")
        expect(body).to have_key("confidence")
        expect(body["forecast"].length).to eq(3)
      end

      it "月数パラメータが反映されること" do
        post "/api/v1/ai/revenue_forecast",
             params: { months: 6 },
             headers: auth_headers(user), as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["forecast"].length).to eq(6)
      end
    end

    context "freeプランの場合" do
      let!(:free_tenant) { create(:tenant, plan: "free") }
      let!(:free_user) { create(:user, :owner, tenant: free_tenant) }

      it "プラン制限エラーになること" do
        post "/api/v1/ai/revenue_forecast",
             headers: auth_headers(free_user), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /api/v1/ai/customer_analysis/:id" do
    context "認証済みユーザーの場合" do
      let!(:invoice) do
        create(:document, :invoice,
               tenant: tenant, customer: customer, created_by_user: user,
               issue_date: 1.month.ago.to_date,
               total_amount: 500_000, paid_amount: 500_000,
               status: "sent", payment_status: "paid")
      end

      it "取引先分析を返すこと" do
        get "/api/v1/ai/customer_analysis/#{customer.uuid}",
            headers: auth_headers(user), as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["customer_id"]).to eq(customer.uuid)
        expect(body["company_name"]).to eq(customer.company_name)
        expect(body).to have_key("statistics")
        expect(body).to have_key("payment_history")
        expect(body).to have_key("risk_assessment")
        expect(body).to have_key("summary")
        expect(body).to have_key("recommendations")
      end
    end

    context "存在しない顧客の場合" do
      it "404エラーを返すこと" do
        get "/api/v1/ai/customer_analysis/non-existent-uuid",
            headers: auth_headers(user), as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "freeプランの場合" do
      let!(:free_tenant) { create(:tenant, plan: "free") }
      let!(:free_user) { create(:user, :owner, tenant: free_tenant) }
      let!(:free_customer) { create(:customer, tenant: free_tenant) }

      it "プラン制限エラーになること" do
        get "/api/v1/ai/customer_analysis/#{free_customer.uuid}",
            headers: auth_headers(free_user), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
