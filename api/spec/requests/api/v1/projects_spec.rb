# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Projects", type: :request do
  let!(:tenant) { create(:tenant, plan: "standard") }
  let!(:owner) { create(:user, :owner, tenant: tenant) }
  let!(:sales) { create(:user, :sales, tenant: tenant) }
  let!(:member) { create(:user, :member, tenant: tenant) }
  let!(:customer) { create(:customer, tenant: tenant, company_name: "テスト株式会社") }
  let!(:project) { create(:project, tenant: tenant, customer: customer, name: "テスト案件A") }

  describe "GET /api/v1/projects" do
    let!(:customer2) { create(:customer, tenant: tenant, company_name: "サンプル商事") }
    let!(:project2) { create(:project, tenant: tenant, customer: customer2, name: "サンプル案件B", status: "won", amount: 500_000) }
    let!(:project3) { create(:project, tenant: tenant, customer: customer, name: "テスト案件C", amount: 1_000_000) }

    context "認証済みユーザーの場合" do
      it "案件一覧が返されること" do
        get "/api/v1/projects", headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["projects"].length).to eq(3)
        expect(body["meta"]["total_count"]).to eq(3)
      end
    end

    context "名前フィルタの場合" do
      it "部分一致で検索されること" do
        get "/api/v1/projects", params: { filter: { q: "テスト" } }, headers: auth_headers(owner)

        body = response.parsed_body
        expect(body["projects"].length).to eq(2)
      end
    end

    context "ステータスフィルタの場合" do
      it "ステータスで絞り込めること" do
        get "/api/v1/projects", params: { filter: { status: "won" } }, headers: auth_headers(owner)

        body = response.parsed_body
        expect(body["projects"].length).to eq(1)
        expect(body["projects"][0]["name"]).to eq("サンプル案件B")
      end
    end

    context "顧客IDフィルタの場合" do
      it "顧客UUIDで絞り込めること" do
        get "/api/v1/projects", params: { filter: { customer_id: customer.uuid } }, headers: auth_headers(owner)

        body = response.parsed_body
        expect(body["projects"].length).to eq(2)
      end
    end

    context "ソートの場合" do
      it "案件名昇順でソートできること" do
        get "/api/v1/projects", params: { sort: "name", order: "asc" }, headers: auth_headers(owner)

        body = response.parsed_body
        names = body["projects"].map { |p| p["name"] }
        expect(names).to eq(names.sort)
      end
    end

    context "論理削除済みの案件の場合" do
      before { project3.soft_delete! }

      it "一覧に含まれないこと" do
        get "/api/v1/projects", headers: auth_headers(owner)

        body = response.parsed_body
        expect(body["projects"].length).to eq(2)
      end
    end

    context "他テナントの案件の場合" do
      let!(:other_tenant) { create(:tenant, name: "他社") }
      let!(:other_customer) { create(:customer, tenant: other_tenant) }
      let!(:other_project) { create(:project, tenant: other_tenant, customer: other_customer, name: "他社案件") }

      it "他テナントの案件が含まれないこと" do
        get "/api/v1/projects", headers: auth_headers(owner)

        body = response.parsed_body
        project_names = body["projects"].map { |p| p["name"] }
        expect(project_names).not_to include("他社案件")
      end
    end
  end

  describe "GET /api/v1/projects/:id" do
    context "認証済みユーザーの場合" do
      it "案件詳細が返されること" do
        get "/api/v1/projects/#{project.uuid}", headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["project"]["id"]).to eq(project.uuid)
        expect(body["project"]["name"]).to eq("テスト案件A")
        expect(body["project"]).to have_key("description")
      end
    end
  end

  describe "POST /api/v1/projects" do
    let!(:valid_params) do
      { project: { name: "新規案件", customer_id: customer.uuid, probability: 50, amount: 1_000_000 } }
    end

    context "sales以上のロールの場合" do
      it "案件が作成されること" do
        expect {
          post "/api/v1/projects", params: valid_params, headers: auth_headers(sales), as: :json
        }.to change(Project, :count).by(1)

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["project"]["name"]).to eq("新規案件")
        expect(body["project"]["project_number"]).to start_with("PJ-")
      end
    end

    context "memberロールの場合" do
      it "403エラーが返されること" do
        post "/api/v1/projects", params: valid_params, headers: auth_headers(member), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "案件名が空の場合" do
      it "422エラーが返されること" do
        post "/api/v1/projects",
             params: { project: { name: "", customer_id: customer.uuid } },
             headers: auth_headers(sales), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "担当者を指定した場合" do
      it "担当者が設定されること" do
        post "/api/v1/projects",
             params: { project: { name: "担当者付き案件", customer_id: customer.uuid, assigned_user_id: sales.uuid } },
             headers: auth_headers(sales), as: :json

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["project"]["assigned_user_id"]).to eq(sales.uuid)
      end
    end
  end

  describe "PATCH /api/v1/projects/:id" do
    context "sales以上のロールの場合" do
      it "案件情報が更新されること" do
        patch "/api/v1/projects/#{project.uuid}",
              params: { project: { name: "更新後の案件名" } },
              headers: auth_headers(sales), as: :json

        expect(response).to have_http_status(:ok)
        expect(project.reload.name).to eq("更新後の案件名")
      end
    end

    context "memberロールの場合" do
      it "403エラーが返されること" do
        patch "/api/v1/projects/#{project.uuid}",
              params: { project: { name: "不正更新" } },
              headers: auth_headers(member), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "DELETE /api/v1/projects/:id" do
    context "admin以上のロールの場合" do
      it "論理削除されること" do
        delete "/api/v1/projects/#{project.uuid}", headers: auth_headers(owner)

        expect(response).to have_http_status(:no_content)
        expect(project.reload.deleted_at).to be_present
      end
    end

    context "salesロールの場合" do
      it "403エラーが返されること" do
        delete "/api/v1/projects/#{project.uuid}", headers: auth_headers(sales)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /api/v1/projects/:id/status" do
    context "正常なステータス遷移の場合" do
      it "ステータスが更新されること" do
        patch "/api/v1/projects/#{project.uuid}/status",
              params: { status: "won" },
              headers: auth_headers(sales), as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["project"]["status"]).to eq("won")
        expect(project.reload.status).to eq("won")
      end
    end

    context "不正なステータス遷移の場合" do
      it "422エラーが返されること" do
        patch "/api/v1/projects/#{project.uuid}/status",
              params: { status: "paid" },
              headers: auth_headers(sales), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "memberロールの場合" do
      it "403エラーが返されること" do
        patch "/api/v1/projects/#{project.uuid}/status",
              params: { status: "won" },
              headers: auth_headers(member), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /api/v1/projects/:id/documents" do
    let!(:doc) do
      create(:document, tenant: tenant, customer: customer, project: project,
             created_by_user: owner, document_type: "estimate", document_number: "EST-001")
    end

    it "案件の帳票一覧が返されること" do
      get "/api/v1/projects/#{project.uuid}/documents", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["documents"].length).to eq(1)
      expect(body["documents"][0]["document_number"]).to eq("EST-001")
    end
  end

  describe "GET /api/v1/projects/pipeline" do
    let!(:project_won) { create(:project, :won, tenant: tenant, customer: customer, amount: 300_000) }
    let!(:project_in_progress) { create(:project, :in_progress, tenant: tenant, customer: customer, amount: 500_000) }

    it "パイプライン集計が返されること" do
      get "/api/v1/projects/pipeline", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["pipeline"]).to be_an(Array)
      statuses = body["pipeline"].map { |p| p["status"] }
      expect(statuses).to include("negotiation")
    end
  end
end
