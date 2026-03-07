# frozen_string_literal: true

require "rails_helper"

RSpec.describe BankStatementImporter do
  let!(:tenant) { create(:tenant) }

  describe ".call" do
    context "汎用CSVフォーマットの場合" do
      let!(:csv_data) do
        <<~CSV
          日付,摘要,金額
          2026/02/01,振込 カ）テスト商事,100000
          2026/02/02,振込 サンプル工業,50000
          2026/02/03,振込 テスト工業,30000
        CSV
      end

      it "明細がインポートされること" do
        result = described_class.call(tenant, csv_data, filename: "meisai.csv")

        expect(result[:imported]).to eq(3)
        expect(result[:skipped]).to eq(0)
        expect(result[:batch_id]).to be_present
        expect(BankStatement.where(tenant: tenant).count).to eq(3)
      end

      it "各フィールドが正しく保存されること" do
        described_class.call(tenant, csv_data, filename: "meisai.csv")

        stmt = BankStatement.where(tenant: tenant).order(:transaction_date).first
        expect(stmt.transaction_date).to eq(Date.new(2026, 2, 1))
        expect(stmt.description).to eq("振込 カ）テスト商事")
        expect(stmt.amount).to eq(100_000)
        expect(stmt.is_matched).to be false
      end
    end

    context "重複データの場合" do
      let!(:csv_data) do
        <<~CSV
          日付,摘要,金額
          2026/02/01,振込 カ）テスト商事,100000
        CSV
      end

      before do
        described_class.call(tenant, csv_data, filename: "meisai.csv")
      end

      it "重複行がスキップされること" do
        result = described_class.call(tenant, csv_data, filename: "meisai2.csv")

        expect(result[:imported]).to eq(0)
        expect(result[:skipped]).to eq(1)
      end
    end

    context "空のCSVの場合" do
      let!(:csv_data) { "日付,摘要,金額\n" }

      it "ImportErrorが発生すること" do
        expect {
          described_class.call(tenant, csv_data, filename: "empty.csv")
        }.to raise_error(BankStatementImporter::ImportError, /データ行がありません/)
      end
    end

    context "不正な行がある場合" do
      let!(:csv_data) do
        <<~CSV
          日付,摘要,金額
          2026/02/01,振込 テスト商事,100000
          ,不正データ,
          2026/02/02,振込 サンプル工業,50000
        CSV
      end

      it "不正行がスキップされて有効行のみインポートされること" do
        result = described_class.call(tenant, csv_data, filename: "meisai.csv")

        expect(result[:imported]).to eq(2)
      end
    end

    context "日本語日付フォーマットの場合" do
      let!(:csv_data) do
        <<~CSV
          日付,摘要,金額
          2026年02月01日,振込 テスト,100000
        CSV
      end

      it "正しくパースされること" do
        result = described_class.call(tenant, csv_data, filename: "meisai.csv")

        expect(result[:imported]).to eq(1)
        stmt = BankStatement.where(tenant: tenant).first
        expect(stmt.transaction_date).to eq(Date.new(2026, 2, 1))
      end
    end

    context "金額にカンマ・円記号がある場合" do
      let!(:csv_data) do
        "日付,摘要,金額\n2026/02/01,振込 テスト,\"¥100,000\"\n"
      end

      it "正しくパースされること" do
        result = described_class.call(tenant, csv_data, filename: "meisai.csv")

        expect(result[:imported]).to eq(1)
        stmt = BankStatement.where(tenant: tenant).first
        expect(stmt.amount).to eq(100_000)
      end
    end

    context "銀行フォーマット指定の場合" do
      let!(:csv_data) do
        <<~CSV
          日付,摘要,金額
          2026/02/01,振込 テスト,100000
        CSV
      end

      it "filenameからフォーマットが検出されること" do
        result = described_class.call(tenant, csv_data, filename: "mufg_202602.csv", bank_format: "generic")

        expect(result[:imported]).to eq(1)
      end
    end
  end
end
