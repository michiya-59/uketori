# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Imports", type: :request do
  let!(:tenant) { create(:tenant) }
  let!(:owner) { create(:user, :owner, tenant: tenant) }
  let!(:member) { create(:user, :member, tenant: tenant) }

  describe "POST /api/v1/imports" do
    let!(:csv_content) { "会社名,電話番号\nテスト株式会社,03-1234-5678\nサンプル有限会社,06-9876-5432" }
    let!(:csv_file) do
      Rack::Test::UploadedFile.new(
        StringIO.new(csv_content), "text/csv", original_filename: "customers.csv"
      )
    end

    context "admin以上のロールの場合" do
      it "インポートジョブが作成されること" do
        expect {
          post "/api/v1/imports", params: { file: csv_file, source_type: "csv_generic" },
               headers: auth_headers(owner)
        }.to change(ImportJob, :count).by(1)

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["import_job"]["status"]).to eq("mapping")
        expect(body["import_job"]["column_mapping"]).to be_present
      end

      it "AIマッピングが実行されること" do
        post "/api/v1/imports", params: { file: csv_file, source_type: "csv_generic" },
             headers: auth_headers(owner)

        body = response.parsed_body
        expect(body["import_job"]["ai_mapping_confidence"]).to be_present
        expect(body["import_job"]["column_mapping"].length).to eq(2)
      end
    end

    context "memberロールの場合" do
      it "403エラーが返されること" do
        post "/api/v1/imports", params: { file: csv_file, source_type: "csv_generic" },
             headers: auth_headers(member)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "ファイルが未指定の場合" do
      it "422エラーが返されること" do
        post "/api/v1/imports", params: { source_type: "csv_generic" },
             headers: auth_headers(owner)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /api/v1/imports/:uuid" do
    let!(:import_job) { create(:import_job, tenant: tenant, user: owner) }

    context "admin以上のロールの場合" do
      it "ジョブ詳細が返されること" do
        get "/api/v1/imports/#{import_job.uuid}", headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["import_job"]["uuid"]).to eq(import_job.uuid)
        expect(body["import_job"]["status"]).to eq("pending")
      end
    end
  end

  describe "GET /api/v1/imports/:uuid/preview" do
    let!(:import_job) do
      create(:import_job, :mapping, tenant: tenant, user: owner)
    end

    it "プレビューデータが返されること" do
      get "/api/v1/imports/#{import_job.uuid}/preview", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["preview"]).to be_an(Array)
      expect(body["total_rows"]).to be_present
    end
  end

  describe "PATCH /api/v1/imports/:uuid/mapping" do
    let!(:import_job) do
      create(:import_job, :mapping, tenant: tenant, user: owner)
    end

    it "マッピングが更新されること" do
      new_mappings = [
        { source: "会社名", target_table: "customers", target_column: "company_name", confidence: 1.0 }
      ]

      patch "/api/v1/imports/#{import_job.uuid}/mapping",
            params: { mappings: new_mappings },
            headers: auth_headers(owner), as: :json

      expect(response).to have_http_status(:ok)
      import_job.reload
      expect(import_job.column_mapping.length).to eq(1)
    end
  end

  describe "POST /api/v1/imports/:uuid/execute" do
    let!(:import_job) do
      create(:import_job, :previewing, tenant: tenant, user: owner)
    end

    it "インポートジョブがキューに登録されること" do
      expect {
        post "/api/v1/imports/#{import_job.uuid}/execute", headers: auth_headers(owner)
      }.to have_enqueued_job(ImportExecutionJob)

      expect(response).to have_http_status(:ok)
    end

    context "実行不可のステータスの場合" do
      let!(:completed_job) { create(:import_job, :completed, tenant: tenant, user: owner) }

      it "422エラーが返されること" do
        post "/api/v1/imports/#{completed_job.uuid}/execute", headers: auth_headers(owner)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /api/v1/imports/:uuid/result" do
    let!(:import_job) do
      create(:import_job, :completed, tenant: tenant, user: owner)
    end

    it "インポート結果が返されること" do
      get "/api/v1/imports/#{import_job.uuid}/result", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["stats"]).to be_present
      expect(body["stats"]["success_count"]).to eq(8)
    end
  end
end
