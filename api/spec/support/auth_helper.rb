# frozen_string_literal: true

# リクエストスペック用の認証ヘルパー
module AuthHelper
  # 指定ユーザーのJWTアクセストークンを含む認証ヘッダーを返す
  #
  # @param user [User] 認証対象ユーザー
  # @return [Hash] Authorizationヘッダーを含むハッシュ
  def auth_headers(user)
    tokens = JwtService.encode(user)
    { "Authorization" => "Bearer #{tokens[:access_token]}" }
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request
end
