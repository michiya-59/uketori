# frozen_string_literal: true

require "rails_helper"

RSpec.describe AiColumnMapper do
  describe ".call" do
    context "boardフォーマットの場合" do
      let!(:headers) { %w[会社名 担当者 メールアドレス 電話番号 住所] }

      it "既知パターンでマッピングされること" do
        result = described_class.call(headers, "board")

        expect(result[:mappings].length).to eq(5)
        company = result[:mappings].find { |m| m[:source] == "会社名" }
        expect(company[:target_table]).to eq("customers")
        expect(company[:target_column]).to eq("company_name")
        expect(company[:confidence]).to be >= 0.90
      end

      it "overall_confidenceが算出されること" do
        result = described_class.call(headers, "board")

        expect(result[:overall_confidence]).to be > 0
        expect(result[:overall_confidence]).to be <= 1.0
      end
    end

    context "DB定義が存在する場合" do
      let!(:definition) do
        create(:import_column_definition,
               source_type: "board",
               source_column_name: "カスタム列",
               target_table: "customers",
               target_column: "notes")
      end
      let!(:headers) { %w[カスタム列] }

      it "DB定義が優先されること" do
        result = described_class.call(headers, "board")

        mapping = result[:mappings].first
        expect(mapping[:target_table]).to eq("customers")
        expect(mapping[:target_column]).to eq("notes")
        expect(mapping[:confidence]).to eq(1.0)
        expect(mapping[:method]).to eq("database")
      end
    end

    context "csv_genericフォーマットの場合" do
      let!(:headers) { %w[会社名 合計金額 発行日] }

      it "汎用パターンでマッピングされること" do
        result = described_class.call(headers, "csv_generic")

        company = result[:mappings].find { |m| m[:source] == "会社名" }
        expect(company[:target_table]).to eq("customers")
        expect(company[:target_column]).to eq("company_name")
      end
    end

    context "不明なヘッダーが含まれる場合" do
      let!(:headers) { %w[会社名 完全に不明なカラム] }

      it "不明カラムのconfidenceが低いこと" do
        result = described_class.call(headers, "csv_generic")

        unknown = result[:mappings].find { |m| m[:source] == "完全に不明なカラム" }
        expect(unknown[:confidence]).to eq(0.0)
      end
    end

    context "帳票関連ヘッダーの場合" do
      let!(:headers) { %w[請求番号 件名 発行日 期限日 合計金額 備考] }

      it "documentsテーブルにマッピングされること" do
        result = described_class.call(headers, "board")

        doc_num = result[:mappings].find { |m| m[:source] == "請求番号" }
        expect(doc_num[:target_table]).to eq("documents")
        expect(doc_num[:target_column]).to eq("document_number")
      end
    end
  end
end
