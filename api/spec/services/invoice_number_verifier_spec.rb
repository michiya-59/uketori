# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceNumberVerifier do
  describe ".verify" do
    let!(:valid_number) { "T1234567890123" }

    context "フォーマットが不正な場合" do
      it "Tプレフィックスがない番号でエラーを返すこと" do
        result = described_class.verify("1234567890123")
        expect(result[:valid]).to be false
        expect(result[:error]).to include("フォーマットが不正")
      end

      it "桁数が不足している番号でエラーを返すこと" do
        result = described_class.verify("T123456")
        expect(result[:valid]).to be false
        expect(result[:error]).to include("フォーマットが不正")
      end

      it "空文字列でエラーを返すこと" do
        result = described_class.verify("")
        expect(result[:valid]).to be false
        expect(result[:error]).to include("フォーマットが不正")
      end

      it "nilでエラーを返すこと" do
        result = described_class.verify(nil)
        expect(result[:valid]).to be false
        expect(result[:error]).to include("フォーマットが不正")
      end
    end

    context "NTA_APP_IDが未設定の場合" do
      before do
        allow(ENV).to receive(:fetch).with("NTA_APP_ID", nil).and_return(nil)
      end

      it "設定不足のエラーを返すこと" do
        result = described_class.verify(valid_number)
        expect(result[:valid]).to be false
        expect(result[:error]).to include("アプリケーションIDが設定されていません")
      end
    end

    context "APIが正常に応答する場合" do
      let!(:success_response) do
        instance_double(
          Net::HTTPOK,
          is_a?: true,
          code: "200",
          body: {
            announcement: [
              {
                "name" => "株式会社サンプル",
                "address" => "東京都千代田区",
                "registrationDate" => "2023-10-01",
                "updateDate" => "2023-10-01"
              }
            ]
          }.to_json
        )
      end

      before do
        allow(ENV).to receive(:fetch).with("NTA_APP_ID", nil).and_return("test-app-id")
        allow(described_class).to receive(:fetch_from_api).and_return(success_response)
        allow(success_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        # レート制限をスキップ
        described_class.last_request_at = nil
      end

      it "有効な結果を返すこと" do
        result = described_class.verify(valid_number)
        expect(result[:valid]).to be true
        expect(result[:name]).to eq("株式会社サンプル")
        expect(result[:address]).to eq("東京都千代田区")
      end
    end

    context "APIが該当なしを返す場合" do
      let!(:empty_response) do
        instance_double(
          Net::HTTPOK,
          code: "200",
          body: { announcement: nil }.to_json
        )
      end

      before do
        allow(ENV).to receive(:fetch).with("NTA_APP_ID", nil).and_return("test-app-id")
        allow(described_class).to receive(:fetch_from_api).and_return(empty_response)
        allow(empty_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        described_class.last_request_at = nil
      end

      it "無効な結果を返すこと" do
        result = described_class.verify(valid_number)
        expect(result[:valid]).to be false
        expect(result[:error]).to include("該当する事業者が見つかりません")
      end
    end

    context "APIがHTTPエラーを返す場合" do
      let!(:error_response) do
        instance_double(
          Net::HTTPInternalServerError,
          code: "500"
        )
      end

      before do
        allow(ENV).to receive(:fetch).with("NTA_APP_ID", nil).and_return("test-app-id")
        allow(described_class).to receive(:fetch_from_api).and_return(error_response)
        allow(error_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
        described_class.last_request_at = nil
      end

      it "HTTPエラーを返すこと" do
        result = described_class.verify(valid_number)
        expect(result[:valid]).to be false
        expect(result[:error]).to include("国税庁APIエラー")
      end
    end

    context "タイムアウトが発生する場合" do
      before do
        allow(ENV).to receive(:fetch).with("NTA_APP_ID", nil).and_return("test-app-id")
        allow(described_class).to receive(:fetch_from_api).and_raise(Net::OpenTimeout, "connection timed out")
        described_class.last_request_at = nil
      end

      it "タイムアウトエラーを返すこと" do
        result = described_class.verify(valid_number)
        expect(result[:valid]).to be false
        expect(result[:error]).to include("タイムアウト")
      end
    end
  end
end
