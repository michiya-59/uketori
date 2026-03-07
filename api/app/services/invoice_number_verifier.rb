# frozen_string_literal: true

# 適格請求書発行事業者の登録番号を国税庁APIで検証するサービス
#
# 国税庁の適格請求書発行事業者公表システムWeb-APIを利用して、
# 登録番号の有効性を確認する。レート制限（1リクエスト/秒）を遵守する。
#
# @example テナントの登録番号を検証
#   result = InvoiceNumberVerifier.verify("T1234567890123")
#   result[:valid]       # => true / false
#   result[:name]        # => "株式会社サンプル"（有効な場合）
#
# @see https://www.invoice-kohyo.nta.go.jp/web-api/index.html
class InvoiceNumberVerifier
  # 国税庁API v1 エンドポイント
  BASE_URL = "https://web-api.invoice-kohyo.nta.go.jp/1"

  # レート制限用のミューテックス
  RATE_LIMIT_MUTEX = Mutex.new
  # 最後のリクエスト時刻
  @last_request_at = nil

  class << self
    # @return [Time, nil] 最後のリクエスト時刻
    attr_accessor :last_request_at

    # 適格請求書番号を検証する
    #
    # @param registration_number [String] 登録番号（T + 13桁の数字）
    # @return [Hash] 検証結果 { valid:, name:, address:, error: }
    def verify(registration_number)
      return invalid_format_result unless valid_format?(registration_number)

      app_id = ENV.fetch("NTA_APP_ID", nil)
      return missing_config_result if app_id.blank?

      enforce_rate_limit!

      response = fetch_from_api(registration_number, app_id)
      parse_response(response)
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      { valid: false, error: "国税庁APIへの接続がタイムアウトしました: #{e.message}" }
    rescue StandardError => e
      { valid: false, error: "検証中にエラーが発生しました: #{e.message}" }
    end

    private

    # 登録番号のフォーマットを検証する
    #
    # @param number [String] 登録番号
    # @return [Boolean] T + 13桁の数字であるか
    def valid_format?(number)
      number.present? && number.match?(/\AT\d{13}\z/)
    end

    # レート制限を適用する（1リクエスト/秒）
    #
    # @return [void]
    def enforce_rate_limit!
      RATE_LIMIT_MUTEX.synchronize do
        if last_request_at
          elapsed = Time.current - last_request_at
          sleep(1.0 - elapsed) if elapsed < 1.0
        end
        self.last_request_at = Time.current
      end
    end

    # 国税庁APIにリクエストを送信する
    #
    # @param registration_number [String] 登録番号
    # @param app_id [String] アプリケーションID
    # @return [Net::HTTPResponse] APIレスポンス
    def fetch_from_api(registration_number, app_id)
      # 登録番号からTを除去した13桁を使用
      number = registration_number.delete_prefix("T")
      today = Date.current.strftime("%Y-%m-%d")
      uri = URI("#{BASE_URL}/num?id=#{app_id}&number=#{number}&day=#{today}&type=21")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 10

      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"

      http.request(request)
    end

    # APIレスポンスをパースして検証結果を返す
    #
    # @param response [Net::HTTPResponse] APIレスポンス
    # @return [Hash] 検証結果
    def parse_response(response)
      unless response.is_a?(Net::HTTPSuccess)
        return { valid: false, error: "国税庁APIエラー: HTTP #{response.code}" }
      end

      body = JSON.parse(response.body)

      # レスポンスにannouncementが含まれるか確認
      announcements = body.dig("announcement")
      if announcements.blank?
        return { valid: false, error: "該当する事業者が見つかりません" }
      end

      announcement = announcements.first
      {
        valid: true,
        name: announcement["name"],
        address: announcement["address"],
        registration_date: announcement["registrationDate"],
        update_date: announcement["updateDate"]
      }
    rescue JSON::ParserError
      { valid: false, error: "国税庁APIのレスポンス解析に失敗しました" }
    end

    # フォーマット不正の結果を返す
    #
    # @return [Hash] エラー結果
    def invalid_format_result
      { valid: false, error: "登録番号のフォーマットが不正です（T + 13桁の数字）" }
    end

    # API設定不足の結果を返す
    #
    # @return [Hash] エラー結果
    def missing_config_result
      { valid: false, error: "国税庁APIのアプリケーションIDが設定されていません" }
    end
  end
end
