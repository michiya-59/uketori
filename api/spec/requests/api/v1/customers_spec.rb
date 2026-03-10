# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Customers", type: :request do
  let!(:tenant) { create(:tenant, plan: "standard") }
  let!(:owner) { create(:user, :owner, tenant: tenant) }
  let!(:sales) { create(:user, :sales, tenant: tenant) }
  let!(:member) { create(:user, :member, tenant: tenant) }
  let!(:customer) { create(:customer, tenant: tenant, company_name: "テスト株式会社") }

  describe "GET /api/v1/customers" do
    let!(:customer2) { create(:customer, tenant: tenant, company_name: "サンプル商事", customer_type: "vendor", credit_score: 80) }
    let!(:customer3) { create(:customer, tenant: tenant, company_name: "テスト工業", credit_score: 20) }

    context "認証済みユーザーの場合" do
      it "顧客一覧が返されること" do
        get "/api/v1/customers", headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["customers"].length).to eq(3)
        expect(body["meta"]["total_count"]).to eq(3)
      end
    end

    context "名前フィルタの場合" do
      it "部分一致で検索されること" do
        get "/api/v1/customers", params: { filter: { q: "テスト" } }, headers: auth_headers(owner)

        body = response.parsed_body
        expect(body["customers"].length).to eq(2)
      end
    end

    context "顧客種別フィルタの場合" do
      it "種別で絞り込めること" do
        get "/api/v1/customers", params: { filter: { customer_type: "vendor" } }, headers: auth_headers(owner)

        body = response.parsed_body
        expect(body["customers"].length).to eq(1)
        expect(body["customers"][0]["company_name"]).to eq("サンプル商事")
      end
    end

    context "与信スコアフィルタの場合" do
      it "スコア範囲で絞り込めること" do
        get "/api/v1/customers", params: { filter: { credit_score_min: 50 } }, headers: auth_headers(owner)

        body = response.parsed_body
        expect(body["customers"].length).to eq(1)
        expect(body["customers"][0]["company_name"]).to eq("サンプル商事")
      end
    end

    context "ソートの場合" do
      it "会社名昇順でソートできること" do
        get "/api/v1/customers", params: { sort: "company_name", order: "asc" }, headers: auth_headers(owner)

        body = response.parsed_body
        names = body["customers"].map { |c| c["company_name"] }
        expect(names).to eq(names.sort)
      end
    end

    context "論理削除済みの顧客の場合" do
      before { customer3.soft_delete! }

      it "一覧に含まれないこと" do
        get "/api/v1/customers", headers: auth_headers(owner)

        body = response.parsed_body
        expect(body["customers"].length).to eq(2)
      end
    end

    context "他テナントの顧客の場合" do
      let!(:other_tenant) { create(:tenant, name: "他社") }
      let!(:other_customer) { create(:customer, tenant: other_tenant, company_name: "他社顧客") }

      it "他テナントの顧客が含まれないこと" do
        get "/api/v1/customers", headers: auth_headers(owner)

        body = response.parsed_body
        company_names = body["customers"].map { |c| c["company_name"] }
        expect(company_names).not_to include("他社顧客")
      end
    end
  end

  describe "GET /api/v1/customers/:id" do
    context "認証済みユーザーの場合" do
      it "顧客詳細が返されること" do
        get "/api/v1/customers/#{customer.uuid}", headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["customer"]["id"]).to eq(customer.uuid)
        expect(body["customer"]["company_name"]).to eq("テスト株式会社")
        expect(body["customer"]).to have_key("contacts")
      end
    end
  end

  describe "POST /api/v1/customers" do
    let!(:valid_params) do
      { customer: { company_name: "新規取引先", company_name_kana: "シンキトリヒキサキ", customer_type: "client", email: "new@example.com" } }
    end

    context "sales以上のロールの場合" do
      it "顧客が作成されること" do
        expect {
          post "/api/v1/customers", params: valid_params, headers: auth_headers(sales), as: :json
        }.to change(Customer, :count).by(1)

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["customer"]["company_name"]).to eq("新規取引先")
      end
    end

    context "memberロールの場合" do
      it "403エラーが返されること" do
        post "/api/v1/customers", params: valid_params, headers: auth_headers(member), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "会社名が空の場合" do
      it "422エラーが返されること" do
        post "/api/v1/customers",
             params: { customer: { company_name: "", customer_type: "client" } },
             headers: auth_headers(sales), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PATCH /api/v1/customers/:id" do
    context "sales以上のロールの場合" do
      it "顧客情報が更新されること" do
        patch "/api/v1/customers/#{customer.uuid}",
              params: { customer: { company_name: "更新後の会社名" } },
              headers: auth_headers(sales), as: :json

        expect(response).to have_http_status(:ok)
        expect(customer.reload.company_name).to eq("更新後の会社名")
      end
    end

    context "memberロールの場合" do
      it "403エラーが返されること" do
        patch "/api/v1/customers/#{customer.uuid}",
              params: { customer: { company_name: "不正更新" } },
              headers: auth_headers(member), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "DELETE /api/v1/customers/:id" do
    context "admin以上のロールの場合" do
      it "論理削除されること" do
        delete "/api/v1/customers/#{customer.uuid}", headers: auth_headers(owner)

        expect(response).to have_http_status(:no_content)
        expect(customer.reload.deleted_at).to be_present
      end
    end

    context "salesロールの場合" do
      it "403エラーが返されること" do
        delete "/api/v1/customers/#{customer.uuid}", headers: auth_headers(sales)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /api/v1/customers/:id/documents" do
    let!(:doc) do
      create(:document, tenant: tenant, customer: customer, created_by_user: owner,
             document_type: "invoice", document_number: "INV-001")
    end

    it "顧客の帳票一覧が返されること" do
      get "/api/v1/customers/#{customer.uuid}/documents", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["documents"].length).to eq(1)
      expect(body["documents"][0]["document_number"]).to eq("INV-001")
    end
  end

  describe "GET /api/v1/customers/:id/credit_history" do
    let!(:accountant) { create(:user, :accountant, tenant: tenant) }
    let!(:history) { create(:credit_score_history, tenant: tenant, customer: customer, score: 75) }

    context "accountant以上のロールの場合" do
      it "与信スコア履歴が返されること" do
        get "/api/v1/customers/#{customer.uuid}/credit_history", headers: auth_headers(accountant)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["credit_history"].length).to eq(1)
        expect(body["credit_history"][0]["score"]).to eq(75)
      end
    end

    context "salesロールの場合" do
      it "403エラーが返されること" do
        get "/api/v1/customers/#{customer.uuid}/credit_history", headers: auth_headers(sales)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "POST /api/v1/customers/:id/verify_invoice_number" do
    context "適格番号が設定されている場合" do
      before { customer.update_columns(invoice_registration_number: "T1234567890123") }

      it "検証ジョブがキューに追加されること" do
        expect {
          post "/api/v1/customers/#{customer.uuid}/verify_invoice_number", headers: auth_headers(sales)
        }.to have_enqueued_job(InvoiceNumberVerificationJob).with("Customer", customer.id)

        expect(response).to have_http_status(:ok)
      end
    end

    context "適格番号が未設定の場合" do
      it "422エラーが返されること" do
        post "/api/v1/customers/#{customer.uuid}/verify_invoice_number", headers: auth_headers(sales)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
