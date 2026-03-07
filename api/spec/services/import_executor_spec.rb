# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImportExecutor do
  let!(:tenant) { create(:tenant) }
  let!(:user) { create(:user, :owner, tenant: tenant) }

  describe ".call" do
    context "顧客データをインポートする場合" do
      let!(:import_job) do
        create(:import_job, tenant: tenant, user: user, status: "previewing",
               parsed_data: {
                 "headers" => %w[会社名 電話番号],
                 "rows" => [
                   %w[テスト株式会社 03-1234-5678],
                   %w[サンプル有限会社 06-9876-5432]
                 ]
               },
               column_mapping: [
                 { "source" => "会社名", "target_table" => "customers", "target_column" => "company_name" },
                 { "source" => "電話番号", "target_table" => "customers", "target_column" => "phone" }
               ])
      end

      it "顧客が作成されること" do
        expect {
          described_class.call(import_job)
        }.to change(Customer, :count).by(2)
      end

      it "成功件数が正しいこと" do
        result = described_class.call(import_job)

        expect(result[:total]).to eq(2)
        expect(result[:success]).to eq(2)
        expect(result[:error]).to eq(0)
      end

      it "ジョブステータスがcompletedになること" do
        described_class.call(import_job)

        import_job.reload
        expect(import_job.status).to eq("completed")
        expect(import_job.completed_at).to be_present
        expect(import_job.import_stats["success_count"]).to eq(2)
      end
    end

    context "重複データがある場合" do
      let!(:existing_customer) { create(:customer, tenant: tenant, company_name: "テスト株式会社") }
      let!(:import_job) do
        create(:import_job, tenant: tenant, user: user, status: "previewing",
               parsed_data: {
                 "headers" => %w[会社名],
                 "rows" => [
                   %w[テスト株式会社],
                   %w[新規会社]
                 ]
               },
               column_mapping: [
                 { "source" => "会社名", "target_table" => "customers", "target_column" => "company_name" }
               ])
      end

      it "重複行がスキップされること" do
        result = described_class.call(import_job)

        expect(result[:success]).to eq(1)
        expect(result[:skipped]).to eq(1)
      end
    end

    context "会社名が空の場合" do
      let!(:import_job) do
        create(:import_job, tenant: tenant, user: user, status: "previewing",
               parsed_data: {
                 "headers" => %w[会社名],
                 "rows" => [
                   [""],
                   %w[有効な会社]
                 ]
               },
               column_mapping: [
                 { "source" => "会社名", "target_table" => "customers", "target_column" => "company_name" }
               ])
      end

      it "エラー行が記録されること" do
        result = described_class.call(import_job)

        expect(result[:success]).to eq(1)
        expect(result[:error]).to eq(1)
        import_job.reload
        expect(import_job.error_details).to be_present
      end
    end

    context "品目データをインポートする場合" do
      let!(:import_job) do
        create(:import_job, tenant: tenant, user: user, status: "previewing",
               parsed_data: {
                 "headers" => %w[品目名 単価],
                 "rows" => [
                   %w[コンサルティング 50000],
                   %w[デザイン作業 30000]
                 ]
               },
               column_mapping: [
                 { "source" => "品目名", "target_table" => "products", "target_column" => "name" },
                 { "source" => "単価", "target_table" => "products", "target_column" => "unit_price" }
               ])
      end

      it "品目が作成されること" do
        expect {
          described_class.call(import_job)
        }.to change(Product, :count).by(2)
      end
    end

    context "顧客と連絡先の複合インポートの場合" do
      let!(:import_job) do
        create(:import_job, tenant: tenant, user: user, status: "previewing",
               parsed_data: {
                 "headers" => %w[会社名 担当者 メールアドレス],
                 "rows" => [
                   %w[テスト株式会社 山田太郎 yamada@example.com]
                 ]
               },
               column_mapping: [
                 { "source" => "会社名", "target_table" => "customers", "target_column" => "company_name" },
                 { "source" => "担当者", "target_table" => "customer_contacts", "target_column" => "name" },
                 { "source" => "メールアドレス", "target_table" => "customer_contacts", "target_column" => "email" }
               ])
      end

      it "顧客と連絡先が作成されること" do
        expect {
          described_class.call(import_job)
        }.to change(Customer, :count).by(1)
          .and change(CustomerContact, :count).by(1)
      end
    end
  end
end
