# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Dashboard", type: :request do
  let!(:tenant) { create(:tenant) }
  let!(:owner) { create(:user, :owner, tenant: tenant) }
  let!(:customer) { create(:customer, tenant: tenant) }

  describe "GET /api/v1/dashboard" do
    context "データが存在しない場合" do
      it "空のKPIが返されること" do
        get "/api/v1/dashboard", headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["kpi"]).to be_present
        expect(body["kpi"]["revenue"]["current"].to_f).to eq(0.0)
        expect(body["alert"]).to be_nil
        expect(body["revenue_trend"]).to be_an(Array)
        expect(body["revenue_trend"].length).to eq(6)
        expect(body["upcoming_payments"]).to eq([])
        expect(body["recent_transactions"]).to eq([])
        expect(body["pipeline"]).to eq([])
        expect(body["period"]).to eq("month")
      end
    end

    context "請求書データが存在する場合" do
      let!(:invoice1) do
        create(:document, :invoice, tenant: tenant, customer: customer,
               created_by_user: owner, issue_date: Date.current,
               total_amount: 100_000, paid_amount: 50_000, remaining_amount: 50_000,
               payment_status: "partial", due_date: Date.current + 5)
      end
      let!(:invoice2) do
        create(:document, :invoice, tenant: tenant, customer: customer,
               created_by_user: owner, issue_date: Date.current,
               total_amount: 200_000, paid_amount: 200_000, remaining_amount: 0,
               payment_status: "paid")
      end
      let!(:overdue_invoice) do
        create(:document, :invoice, tenant: tenant, customer: customer,
               created_by_user: owner, issue_date: Date.current,
               total_amount: 50_000, paid_amount: 0, remaining_amount: 50_000,
               payment_status: "overdue", due_date: Date.current - 10)
      end

      it "KPIが正しく集計されること" do
        get "/api/v1/dashboard", headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        kpi = body["kpi"]
        # 今月の売上 = 100,000 + 200,000 + 50,000 = 350,000
        expect(kpi["revenue"]["current"].to_f).to eq(350_000.0)
        # 未収残高 = partial(50,000) + overdue(50,000) = 100,000
        expect(kpi["outstanding"]["amount"].to_f).to eq(100_000.0)
        expect(kpi["outstanding"]["overdue_count"]).to eq(1)
        # 回収率 = (50,000 + 200,000) / 350,000 * 100 ≈ 71.4%
        expect(kpi["collection_rate"]["current"]).to eq(71.4)
      end

      it "遅延アラートが返されること" do
        get "/api/v1/dashboard", headers: auth_headers(owner)

        body = response.parsed_body
        expect(body["alert"]).to be_present
        expect(body["alert"]["overdue_count"]).to eq(1)
        expect(body["alert"]["overdue_amount"].to_f).to eq(50_000.0)
      end

      it "入金予定が返されること" do
        get "/api/v1/dashboard", headers: auth_headers(owner)

        body = response.parsed_body
        expect(body["upcoming_payments"].length).to eq(1)
        expect(body["upcoming_payments"][0]["document_number"]).to eq(invoice1.document_number)
      end

      it "最近の取引が返されること" do
        get "/api/v1/dashboard", headers: auth_headers(owner)

        body = response.parsed_body
        expect(body["recent_transactions"].length).to eq(3)
      end

      it "売上推移が6ヶ月分返されること" do
        get "/api/v1/dashboard", headers: auth_headers(owner)

        body = response.parsed_body
        trend = body["revenue_trend"]
        expect(trend.length).to eq(6)
        # 最新月に集計値が含まれる
        current_month = Date.current.strftime("%Y-%m")
        current_entry = trend.find { |t| t["month"] == current_month }
        expect(current_entry["invoiced"].to_f).to eq(350_000.0)
      end
    end

    context "案件パイプラインが存在する場合" do
      let!(:project1) { create(:project, tenant: tenant, customer: customer, status: "negotiation", amount: 500_000) }
      let!(:project2) { create(:project, tenant: tenant, customer: customer, status: "in_progress", amount: 300_000) }

      it "パイプラインサマリーが返されること" do
        get "/api/v1/dashboard", headers: auth_headers(owner)

        body = response.parsed_body
        pipeline = body["pipeline"]
        expect(pipeline.length).to eq(2)
        statuses = pipeline.map { |p| p["status"] }
        expect(statuses).to include("negotiation", "in_progress")
      end
    end

    context "periodパラメータを指定する場合" do
      it "quarterを指定するとperiodがquarterで返されること" do
        get "/api/v1/dashboard", params: { period: "quarter" }, headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["period"]).to eq("quarter")
      end

      it "yearを指定するとperiodがyearで返されること" do
        get "/api/v1/dashboard", params: { period: "year" }, headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["period"]).to eq("year")
      end
    end

    context "認証なしの場合" do
      it "401エラーが返されること" do
        get "/api/v1/dashboard"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
