# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Collection", type: :request do
  let!(:tenant) { create(:tenant) }
  let!(:owner) { create(:user, :owner, tenant: tenant) }
  let!(:customer) { create(:customer, tenant: tenant) }
  let!(:invoice) do
    create(:document, :invoice, tenant: tenant, customer: customer, created_by_user: owner,
           total_amount: 100_000, remaining_amount: 100_000, payment_status: "unpaid",
           due_date: 5.days.from_now.to_date)
  end
  let!(:overdue_invoice) do
    create(:document, :invoice, tenant: tenant, customer: customer, created_by_user: owner,
           total_amount: 50_000, remaining_amount: 50_000, payment_status: "overdue",
           due_date: 10.days.ago.to_date)
  end

  describe "GET /api/v1/collection/dashboard" do
    it "ダッシュボードKPIが返されること" do
      get "/api/v1/collection/dashboard", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to have_key("outstanding_total")
      expect(body).to have_key("overdue_amount")
      expect(body).to have_key("overdue_count")
      expect(body).to have_key("collection_rate")
      expect(body).to have_key("avg_dso")
      expect(body).to have_key("aging_summary")
      expect(body).to have_key("at_risk_customers")
      expect(body).to have_key("monthly_trend")
      expect(body).to have_key("unmatched_count")
    end

    it "未回収合計が正しいこと" do
      get "/api/v1/collection/dashboard", headers: auth_headers(owner)

      body = response.parsed_body
      expect(body["outstanding_total"]).to eq(150_000)
      expect(body["overdue_amount"]).to eq(50_000)
      expect(body["overdue_count"]).to eq(1)
    end

    it "エイジングサマリーが返されること" do
      get "/api/v1/collection/dashboard", headers: auth_headers(owner)

      body = response.parsed_body
      aging = body["aging_summary"]
      expect(aging).to have_key("current")
      expect(aging).to have_key("days_1_30")
      expect(aging).to have_key("days_31_60")
      expect(aging).to have_key("days_61_90")
      expect(aging).to have_key("days_over_90")
    end
  end

  describe "GET /api/v1/collection/aging_report" do
    it "エイジングレポートが返されること" do
      get "/api/v1/collection/aging_report", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["customers"].length).to be >= 1
      expect(body["customers"][0]).to have_key("credit_score")
      expect(body["customers"][0]).to have_key("current")
      expect(body["customers"][0]).to have_key("total_outstanding")
    end
  end

  describe "GET /api/v1/collection/forecast" do
    it "入金予測が返されること" do
      get "/api/v1/collection/forecast", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["forecast"].length).to eq(12)
      expect(body["forecast"][0]).to have_key("week_start")
      expect(body["forecast"][0]).to have_key("expected_amount")
    end
  end
end
