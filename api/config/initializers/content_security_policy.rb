# frozen_string_literal: true

# Content-Security-Policy ヘッダー設定（REQ-SEC-001）
#
# XSS対策としてCSPヘッダーをレスポンスに付与する。
# API-onlyアプリケーションのため最小限の設定とする。
Rails.application.config.middleware.insert_before 0, Rack::Head

# ActionDispatch::ContentSecurityPolicy::Middleware が API mode では
# デフォルトで有効にならないため、ミドルウェアで直接ヘッダーを設定する
Rails.application.config.action_dispatch.default_headers.merge!(
  "Content-Security-Policy" => "default-src 'none'; frame-ancestors 'none'",
  "X-Content-Type-Options" => "nosniff",
  "X-Frame-Options" => "DENY",
  "X-XSS-Protection" => "0",
  "Referrer-Policy" => "strict-origin-when-cross-origin"
)
