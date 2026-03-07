class Rack::Attack
  # 全体レートリミット: 100リクエスト/分/IP
  throttle("req/ip", limit: 100, period: 1.minute) do |req|
    req.ip
  end

  # 認証済みAPIレートリミット: 300リクエスト/分/ユーザー
  throttle("api/user", limit: 300, period: 1.minute) do |req|
    if req.path.start_with?("/api/") && req.env["HTTP_AUTHORIZATION"].present?
      # JWTトークンをキーとして使用（ユーザー単位のレートリミット）
      req.env["HTTP_AUTHORIZATION"]
    end
  end

  # ログイン試行: 5回/5分/IP+メール
  throttle("logins/ip", limit: 5, period: 5.minutes) do |req|
    if req.path == "/api/v1/auth/sign_in" && req.post?
      req.ip
    end
  end

  # パスワードリセット試行: 3回/15分/IP
  throttle("password_reset/ip", limit: 3, period: 15.minutes) do |req|
    if req.path == "/api/v1/auth/password" && req.post?
      req.ip
    end
  end

  # レートリミット超過レスポンス
  self.throttled_responder = lambda do |_req|
    [
      429,
      { "Content-Type" => "application/json" },
      [{ error: { code: "rate_limited", message: "リクエストが多すぎます。しばらくしてからお試しください。" } }.to_json]
    ]
  end
end
