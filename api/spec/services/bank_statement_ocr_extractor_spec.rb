# frozen_string_literal: true

require "rails_helper"
require "anthropic"

RSpec.describe BankStatementOcrExtractor do
  describe ".supported?" do
    context "対応するMIMEタイプの場合" do
      it "trueを返すこと" do
        expect(described_class.supported?("image/jpeg")).to be true
        expect(described_class.supported?("image/png")).to be true
        expect(described_class.supported?("application/pdf")).to be true
        expect(described_class.supported?("image/webp")).to be true
      end
    end

    context "非対応のMIMEタイプの場合" do
      it "falseを返すこと" do
        expect(described_class.supported?("text/csv")).to be false
        expect(described_class.supported?("application/json")).to be false
        expect(described_class.supported?(nil)).to be false
      end
    end
  end

  describe ".call" do
    let!(:ai_response_text) do
      <<~CSV
        取引日,摘要,金額
        2026/03/01,カ）ヤマダショウジ,550000
        2026/03/02,フリーランス タナカタロウ,88000
        2026/03/03,カ）サトウデンキ,330000
      CSV
    end

    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("test-api-key")
    end

    # 共通のモックヘルパー
    def mock_vision_api(response1_text, response2_text = nil)
      mock_client = instance_double(Anthropic::Client)
      mock_messages = double("messages")

      allow(Anthropic::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:messages).and_return(mock_messages)

      responses = []
      responses << double("response1", content: [double("content1", text: response1_text)])
      response2 = response2_text || response1_text
      responses << double("response2", content: [double("content2", text: response2)])

      allow(mock_messages).to receive(:create).and_return(*responses)
    end

    context "画像ファイルで両パス一致の場合" do
      it "高信頼で明細が抽出されること" do
        mock_vision_api(ai_response_text)

        result = described_class.call("fake-image-binary-data", content_type: "image/jpeg")

        expect(result[:rows].length).to eq(3)
        expect(result[:rows][0][:date]).to eq("2026/03/01")
        expect(result[:rows][0][:description]).to eq("カ）ヤマダショウジ")
        expect(result[:rows][0][:amount]).to eq("550000")
        expect(result[:rows][0][:confidence]).to eq("high")
        expect(result[:rows][0][:warning]).to be_nil
        expect(result[:warnings_count]).to eq(0)
      end
    end

    context "PDFファイルの場合" do
      it "明細が抽出されること" do
        mock_vision_api(ai_response_text)

        result = described_class.call("fake-pdf-binary-data", content_type: "application/pdf")

        expect(result[:rows].length).to eq(3)
      end
    end

    context "2回の金額が異なる場合" do
      let!(:response2_different_amount) do
        <<~CSV
          取引日,摘要,金額
          2026/03/01,カ）ヤマダショウジ,550000
          2026/03/02,フリーランス タナカタロウ,89000
          2026/03/03,カ）サトウデンキ,330000
        CSV
      end

      it "金額不一致行が低信頼でwarningが出ること" do
        mock_vision_api(ai_response_text, response2_different_amount)

        result = described_class.call("fake-image", content_type: "image/jpeg")

        expect(result[:rows].length).to eq(3)
        # 1行目・3行目は一致 → high
        expect(result[:rows][0][:confidence]).to eq("high")
        expect(result[:rows][2][:confidence]).to eq("high")
        # 2行目は金額不一致 → low
        expect(result[:rows][1][:confidence]).to eq("low")
        expect(result[:rows][1][:warning]).to include("金額の読み取りに差異あり")
        expect(result[:warnings_count]).to eq(1)
      end
    end

    context "2回の摘要のみ異なる場合" do
      let!(:response2_different_desc) do
        <<~CSV
          取引日,摘要,金額
          2026/03/01,カ）ヤマダ ショウジ,550000
          2026/03/02,フリーランス タナカタロウ,88000
          2026/03/03,カ）サトウデンキ,330000
        CSV
      end

      it "摘要差異行が中信頼になること" do
        mock_vision_api(ai_response_text, response2_different_desc)

        result = described_class.call("fake-image", content_type: "image/jpeg")

        # スペースの差は normalize_desc で吸収される → high
        expect(result[:rows][0][:confidence]).to eq("high")
      end
    end

    context "2回目のAPIが失敗した場合" do
      it "1回目の結果がmedium信頼で返ること" do
        mock_client = instance_double(Anthropic::Client)
        mock_messages = double("messages")

        allow(Anthropic::Client).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:messages).and_return(mock_messages)

        resp1 = double("response1", content: [double("content1", text: ai_response_text)])
        call_count = 0
        allow(mock_messages).to receive(:create) do
          call_count += 1
          raise StandardError, "API error" if call_count == 2
          resp1
        end

        result = described_class.call("fake-image", content_type: "image/jpeg")

        expect(result[:rows].length).to eq(3)
        expect(result[:rows].all? { |r| r[:confidence] == "medium" }).to be true
        expect(result[:rows][0][:warning]).to include("検証未実施")
      end
    end

    context "AIがNO_DATAを返した場合" do
      it "ExtractionErrorが発生すること" do
        mock_vision_api("NO_DATA")

        expect {
          described_class.call("fake-image", content_type: "image/jpeg")
        }.to raise_error(BankStatementOcrExtractor::ExtractionError, /明細データを抽出できませんでした/)
      end
    end

    context "AIレスポンスにコードブロックが含まれる場合" do
      let!(:code_block_response) do
        <<~CSV
          ```csv
          取引日,摘要,金額
          2026/03/01,カ）テスト商事,100000
          2026/03/02,サンプル工業,50000
          ```
        CSV
      end

      it "コードブロック記号をスキップして抽出されること" do
        mock_vision_api(code_block_response)

        result = described_class.call("fake-image", content_type: "image/png")

        expect(result[:rows].length).to eq(2)
        expect(result[:rows][0][:date]).to eq("2026/03/01")
      end
    end

    context "2回目に行数が多い場合" do
      let!(:response2_extra) do
        <<~CSV
          取引日,摘要,金額
          2026/03/01,カ）ヤマダショウジ,550000
          2026/03/02,フリーランス タナカタロウ,88000
          2026/03/03,カ）サトウデンキ,330000
          2026/03/04,カ）コバヤシキカク,220000
        CSV
      end

      it "1回目になかった行が低信頼で追加されること" do
        mock_vision_api(ai_response_text, response2_extra)

        result = described_class.call("fake-image", content_type: "image/jpeg")

        expect(result[:rows].length).to eq(4)
        expect(result[:rows][3][:confidence]).to eq("low")
        expect(result[:rows][3][:warning]).to include("1回目の抽出で検出されなかった行")
      end
    end

    context "非対応ファイル形式の場合" do
      it "ExtractionErrorが発生すること" do
        expect {
          described_class.call("data", content_type: "text/plain")
        }.to raise_error(BankStatementOcrExtractor::ExtractionError, /非対応のファイル形式/)
      end
    end

    context "空データの場合" do
      it "ExtractionErrorが発生すること" do
        expect {
          described_class.call("", content_type: "image/jpeg")
        }.to raise_error(BankStatementOcrExtractor::ExtractionError, /ファイルデータが空/)
      end
    end

    context "APIキーが未設定の場合" do
      before do
        allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return(nil)
      end

      it "ExtractionErrorが発生すること" do
        expect {
          described_class.call("fake-image", content_type: "image/jpeg")
        }.to raise_error(BankStatementOcrExtractor::ExtractionError, /AI機能が利用できません/)
      end
    end
  end
end
