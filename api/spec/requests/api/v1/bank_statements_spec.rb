# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::BankStatements", type: :request do
  let!(:tenant) { create(:tenant) }
  let!(:owner) { create(:user, :owner, tenant: tenant) }
  let!(:accountant) { create(:user, :accountant, tenant: tenant) }
  let!(:member) { create(:user, :member, tenant: tenant) }
  let!(:customer) { create(:customer, tenant: tenant, company_name: "テスト株式会社") }
  let!(:invoice) do
    create(:document, :invoice, tenant: tenant, customer: customer, created_by_user: owner,
           total_amount: 100_000, remaining_amount: 100_000, payment_status: "unpaid")
  end
  let!(:batch_id) { "test-batch-001" }

  describe "GET /api/v1/bank_statements" do
    let!(:stmt1) { create(:bank_statement, tenant: tenant, transaction_date: 2.days.ago.to_date, import_batch_id: batch_id) }
    let!(:stmt2) { create(:bank_statement, tenant: tenant, transaction_date: 1.day.ago.to_date, import_batch_id: batch_id) }

    context "認証済みユーザーの場合" do
      it "銀行明細一覧が返されること" do
        get "/api/v1/bank_statements", headers: auth_headers(member)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["bank_statements"].length).to eq(2)
        expect(body["meta"]["total_count"]).to eq(2)
      end
    end

    context "他テナントの明細の場合" do
      let!(:other_tenant) { create(:tenant, name: "他社") }
      let!(:other_stmt) { create(:bank_statement, tenant: other_tenant, import_batch_id: "other") }

      it "他テナントの明細が含まれないこと" do
        get "/api/v1/bank_statements", headers: auth_headers(member)

        body = response.parsed_body
        ids = body["bank_statements"].map { |s| s["id"] }
        expect(ids).not_to include(other_stmt.id)
      end
    end
  end

  describe "POST /api/v1/bank_statements/import" do
    let!(:csv_content) do
      "日付,摘要,金額\n2026/02/01,振込 テスト商事,100000\n2026/02/02,振込 サンプル工業,50000\n"
    end
    let!(:csv_file) do
      Rack::Test::UploadedFile.new(
        StringIO.new(csv_content), "text/csv", original_filename: "meisai.csv"
      )
    end

    context "accountant以上のロールの場合" do
      it "明細がインポートされること" do
        expect {
          post "/api/v1/bank_statements/import",
               params: { file: csv_file },
               headers: auth_headers(accountant)
        }.to change(BankStatement, :count).by(2)

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["imported"]).to eq(2)
        expect(body["skipped"]).to eq(0)
        expect(body["batch_id"]).to be_present
      end

      it "AiBankMatchJobがキューに投入されること" do
        expect {
          post "/api/v1/bank_statements/import",
               params: { file: csv_file },
               headers: auth_headers(accountant)
        }.to have_enqueued_job(AiBankMatchJob)
      end
    end

    context "memberロールの場合" do
      it "403エラーが返されること" do
        post "/api/v1/bank_statements/import",
             params: { file: csv_file },
             headers: auth_headers(member)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "ファイルが指定されていない場合" do
      it "422エラーが返されること" do
        post "/api/v1/bank_statements/import",
             params: {},
             headers: auth_headers(accountant)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /api/v1/bank_statements/unmatched" do
    let!(:unmatched) { create(:bank_statement, :unmatched, tenant: tenant, import_batch_id: batch_id) }
    let!(:matched) { create(:bank_statement, :matched, tenant: tenant, import_batch_id: batch_id) }

    it "未消込の明細のみ返されること" do
      get "/api/v1/bank_statements/unmatched", headers: auth_headers(member)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["bank_statements"].length).to eq(1)
      expect(body["bank_statements"][0]["is_matched"]).to be false
    end
  end

  describe "POST /api/v1/bank_statements/:id/match" do
    let!(:statement) { create(:bank_statement, :unmatched, tenant: tenant, amount: 100_000, import_batch_id: batch_id) }

    context "accountant以上のロールの場合" do
      it "手動マッチングが実行されること" do
        post "/api/v1/bank_statements/#{statement.id}/match",
             params: { document_uuid: invoice.uuid },
             headers: auth_headers(accountant), as: :json

        expect(response).to have_http_status(:ok)
        statement.reload
        expect(statement.is_matched).to be true
        expect(statement.matched_document_id).to eq(invoice.id)
      end

      it "入金レコードが作成されること" do
        expect {
          post "/api/v1/bank_statements/#{statement.id}/match",
               params: { document_uuid: invoice.uuid },
               headers: auth_headers(accountant), as: :json
        }.to change(PaymentRecord, :count).by(1)
      end
    end

    context "memberロールの場合" do
      it "403エラーが返されること" do
        post "/api/v1/bank_statements/#{statement.id}/match",
             params: { document_uuid: invoice.uuid },
             headers: auth_headers(member), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "POST /api/v1/bank_statements/:id/ai_suggest" do
    let!(:statement) { create(:bank_statement, :unmatched, tenant: tenant, amount: 100_000, payer_name: "テスト株式会社", import_batch_id: batch_id) }

    context "accountant以上のロールの場合" do
      it "AI提案が返されること" do
        post "/api/v1/bank_statements/#{statement.id}/ai_suggest",
             headers: auth_headers(accountant)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["suggestion"]).to be_present
        expect(body["suggestion"]["document_uuid"]).to eq(invoice.uuid)
      end
    end
  end

  describe "POST /api/v1/bank_statements/ai_match" do
    let!(:stmt) do
      create(:bank_statement, :unmatched, tenant: tenant, amount: 100_000,
             payer_name: "テスト株式会社", import_batch_id: batch_id)
    end

    context "accountant以上のロールの場合" do
      before { tenant.update!(plan: "starter") }

      it "AIマッチング結果が返されること" do
        post "/api/v1/bank_statements/ai_match",
             params: { batch_id: batch_id },
             headers: auth_headers(accountant), as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body).to have_key("auto_matched")
        expect(body).to have_key("needs_review")
        expect(body).to have_key("unmatched")
      end
    end
  end
end
