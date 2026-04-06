# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Documents", type: :request do
  let!(:tenant) { create(:tenant) }
  let!(:owner) { create(:user, :owner, tenant: tenant) }
  let!(:sales) { create(:user, :sales, tenant: tenant) }
  let!(:accountant) { create(:user, :accountant, tenant: tenant) }
  let!(:member) { create(:user, :member, tenant: tenant) }
  let!(:customer) { create(:customer, tenant: tenant) }
  let!(:document) do
    create(:document, tenant: tenant, customer: customer, created_by_user: owner,
           document_type: "estimate", status: "draft")
  end

  describe "GET /api/v1/documents" do
    let!(:invoice) do
      create(:document, tenant: tenant, customer: customer, created_by_user: owner,
             document_type: "invoice", payment_status: "unpaid")
    end

    context "認証済みユーザーの場合" do
      it "帳票一覧が返されること" do
        get "/api/v1/documents", headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["documents"].length).to eq(2)
      end
    end

    context "帳票タイプフィルタの場合" do
      it "タイプで絞り込めること" do
        get "/api/v1/documents", params: { filter: { document_type: "invoice" } }, headers: auth_headers(owner)

        body = response.parsed_body
        expect(body["documents"].length).to eq(1)
        expect(body["documents"][0]["document_type"]).to eq("invoice")
      end
    end

    context "ステータスフィルタの場合" do
      it "ステータスで絞り込めること" do
        get "/api/v1/documents", params: { filter: { status: "draft" } }, headers: auth_headers(owner)

        body = response.parsed_body
        expect(body["documents"].all? { |d| d["status"] == "draft" }).to be true
      end
    end
  end

  describe "GET /api/v1/documents/:id" do
    it "帳票詳細が返されること" do
      get "/api/v1/documents/#{document.uuid}", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["document"]["id"]).to eq(document.uuid)
      expect(body["document"]).to have_key("items")
    end
  end

  describe "POST /api/v1/documents" do
    let!(:valid_params) do
      {
        document: {
          document_type: "estimate",
          customer_id: customer.uuid,
          title: "テスト見積書",
          issue_date: Date.current.to_s,
          document_items_attributes: [
            { name: "品目1", quantity: 2, unit_price: 10_000, tax_rate: 10.0, tax_rate_type: "standard", item_type: "normal", sort_order: 0 },
            { name: "品目2", quantity: 1, unit_price: 5_000, tax_rate: 8.0, tax_rate_type: "reduced", item_type: "normal", sort_order: 1 }
          ]
        }
      }
    end

    context "sales以上のロールの場合" do
      it "帳票と明細行が作成され金額が計算されること" do
        expect {
          post "/api/v1/documents", params: valid_params, headers: auth_headers(sales), as: :json
        }.to change(Document, :count).by(1).and change(DocumentItem, :count).by(2)

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["document"]["title"]).to eq("テスト見積書")
        expect(body["document"]["subtotal_amount"]).to eq(25_000)
        expect(body["document"]["total_amount"]).to eq(27_400)
        expect(body["document"]["document_number"]).to be_present
        expect(body["document"]["items"].length).to eq(2)
      end

      it "バージョンが作成されること" do
        expect {
          post "/api/v1/documents", params: valid_params, headers: auth_headers(sales), as: :json
        }.to change(DocumentVersion, :count).by(1)
      end

      it "監査ログが記録されること" do
        expect {
          post "/api/v1/documents", params: valid_params, headers: auth_headers(sales), as: :json
        }.to change(AuditLog, :count).by(1)
      end
    end

    context "memberロールの場合" do
      it "403エラーが返されること" do
        post "/api/v1/documents", params: valid_params, headers: auth_headers(member), as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /api/v1/documents/:id" do
    it "帳票が更新されること" do
      patch "/api/v1/documents/#{document.uuid}",
            params: { document: { title: "更新タイトル" } },
            headers: auth_headers(sales), as: :json

      expect(response).to have_http_status(:ok)
      expect(document.reload.title).to eq("更新タイトル")
    end

    context "ロック済みの帳票の場合" do
      before { document.update!(status: "locked", locked_at: Time.current) }

      it "422エラーが返されること" do
        patch "/api/v1/documents/#{document.uuid}",
              params: { document: { title: "不正更新" } },
              headers: auth_headers(owner), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /api/v1/documents/:id" do
    context "admin以上のロールの場合" do
      it "論理削除されること" do
        delete "/api/v1/documents/#{document.uuid}", headers: auth_headers(owner)

        expect(response).to have_http_status(:no_content)
        expect(document.reload.deleted_at).to be_present
      end
    end
  end

  describe "POST /api/v1/documents/:id/duplicate" do
    before do
      create(:document_item, document: document, name: "品目A", quantity: 1, unit_price: 10_000, tax_rate: 10.0)
    end

    it "帳票が複製されること" do
      expect {
        post "/api/v1/documents/#{document.uuid}/duplicate", headers: auth_headers(sales)
      }.to change(Document, :count).by(1)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["document"]["status"]).to eq("draft")
      expect(body["document"]["document_number"]).not_to eq(document.document_number)
    end
  end

  describe "POST /api/v1/documents/:id/convert" do
    context "見積書→請求書の場合" do
      it "請求書に変換されること" do
        post "/api/v1/documents/#{document.uuid}/convert",
             params: { target_type: "invoice" },
             headers: auth_headers(sales), as: :json

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["document"]["document_type"]).to eq("invoice")
        expect(body["document"]["status"]).to eq("draft")
      end
    end

    context "不正な変換の場合" do
      it "422エラーが返されること" do
        post "/api/v1/documents/#{document.uuid}/convert",
             params: { target_type: "receipt" },
             headers: auth_headers(sales), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "未入金の請求書を領収書に変換する場合" do
      let!(:invoice_document) do
        create(:document, tenant: tenant, customer: customer, created_by_user: owner,
               document_type: "invoice", payment_status: "unpaid", remaining_amount: 10_000)
      end

      it "422エラーが返されること" do
        post "/api/v1/documents/#{invoice_document.uuid}/convert",
             params: { target_type: "receipt" },
             headers: auth_headers(sales), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "POST /api/v1/documents/:id/approve" do
    it "承認ステータスに遷移すること" do
      post "/api/v1/documents/#{document.uuid}/approve", headers: auth_headers(accountant)

      expect(response).to have_http_status(:ok)
      expect(document.reload.status).to eq("approved")
    end

    context "不正な遷移の場合" do
      before { document.update!(status: "locked") }

      it "422エラーが返されること" do
        post "/api/v1/documents/#{document.uuid}/approve", headers: auth_headers(accountant)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "POST /api/v1/documents/:id/lock" do
    before { document.update!(status: "sent") }

    it "ロック済みに遷移しlocked_atが記録されること" do
      post "/api/v1/documents/#{document.uuid}/lock", headers: auth_headers(accountant)

      expect(response).to have_http_status(:ok)
      document.reload
      expect(document.status).to eq("locked")
      expect(document.locked_at).to be_present
    end
  end

  describe "GET /api/v1/documents/:id/versions" do
    before do
      create(:document_version, document: document, changed_by_user: owner, version: 1, change_reason: "作成")
    end

    it "バージョン履歴が返されること" do
      get "/api/v1/documents/#{document.uuid}/versions", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["versions"].length).to eq(1)
      expect(body["versions"][0]["change_reason"]).to eq("作成")
    end
  end
end
