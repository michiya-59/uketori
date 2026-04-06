# frozen_string_literal: true

# 全コントローラーのベースクラス
#
# JWT認証・テナントスコープ・エラーハンドリングを提供する。
# 個別コントローラーで `before_action :authenticate_user!` を使用して認証を適用する。
class ApplicationController < ActionController::API
  include Pundit::Authorization

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity_error
  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  rescue_from ActionController::ParameterMissing, with: :bad_request
  rescue_from PlanLimitExceededError, with: :plan_limit_exceeded
  rescue_from IpRestrictedError, with: :ip_restricted

  private

  # リクエストのJWTトークンを検証し、Current.user と Current.tenant を設定する
  #
  # Authorizationヘッダーから Bearer トークンを取得し、JwtServiceで検証する。
  # 認証失敗時は401レスポンスを返す。
  #
  # @return [void]
  def authenticate_user!
    token = extract_token_from_header
    if token.blank?
      render_unauthorized("Authorization header is missing")
      return
    end

    user = JwtService.authenticate(token)
    if user.nil?
      render_unauthorized("Invalid or expired token")
      return
    end

    Current.user = user
    Current.tenant = user.tenant
  end

  # 現在認証されているユーザーを返す
  #
  # @return [User, nil] 認証済みユーザー
  def current_user
    Current.user
  end

  # 現在のテナントを返す
  #
  # @return [Tenant, nil] 現在のテナント
  def current_tenant
    Current.tenant
  end

  # クライアントの実IPアドレスを取得する
  #
  # プロキシ/CDN経由のヘッダーを優先的に参照し、本番環境でもローカル開発でも
  # 正しいクライアントIPを返す。
  #
  # 優先順位:
  #   1. CF-Connecting-IP (Cloudflare)
  #   2. X-Real-IP (Nginx等)
  #   3. X-Forwarded-For の先頭IP
  #   4. request.remote_ip (フォールバック)
  #
  # @return [String] クライアントIPアドレス
  def client_ip
    request.headers["CF-Connecting-IP"].presence ||
      request.headers["X-Real-IP"].presence ||
      request.headers["X-Forwarded-For"]&.split(",")&.first&.strip.presence ||
      request.remote_ip
  end

  # Authorizationヘッダーからベアラートークンを抽出する
  #
  # @return [String, nil] トークン文字列
  def extract_token_from_header
    header = request.headers["Authorization"]
    return nil unless header&.start_with?("Bearer ")

    header.split(" ").last
  end

  # Pundit のユーザーオブジェクトとして現在のユーザーを返す
  #
  # @return [User, nil]
  def pundit_user
    current_user
  end

  # 401 Unauthorized レスポンスを返す
  #
  # @param message [String] エラーメッセージ
  # @return [void]
  def render_unauthorized(message = "Unauthorized")
    render json: { error: { code: "unauthorized", message: message } }, status: :unauthorized
  end

  # 404 Not Found レスポンスを返す
  #
  # @param _exception [ActiveRecord::RecordNotFound]
  # @return [void]
  def not_found(_exception = nil)
    render json: { error: { code: "not_found", message: "Resource not found" } }, status: :not_found
  end

  # 422 Unprocessable Entity レスポンスを返す
  #
  # @param exception [ActiveRecord::RecordInvalid]
  # @return [void]
  def unprocessable_entity_error(exception)
    render json: {
      error: {
        code: "unprocessable_entity",
        message: exception.record.errors.full_messages.join(", "),
        details: exception.record.errors.messages
      }
    }, status: :unprocessable_entity
  end

  # 403 Forbidden レスポンスを返す
  #
  # @param _exception [Pundit::NotAuthorizedError]
  # @return [void]
  def forbidden(_exception = nil)
    render json: { error: { code: "forbidden", message: "You are not authorized to perform this action" } }, status: :forbidden
  end

  # 400 Bad Request レスポンスを返す
  #
  # @param exception [ActionController::ParameterMissing]
  # @return [void]
  def bad_request(exception)
    render json: { error: { code: "bad_request", message: exception.message } }, status: :bad_request
  end

  # 422 プラン制限超過レスポンスを返す
  #
  # @param exception [PlanLimitExceededError]
  # @return [void]
  def plan_limit_exceeded(exception)
    render json: { error: { code: "plan_limit_exceeded", message: exception.message } }, status: :unprocessable_entity
  end

  # 403 IP制限レスポンスを返す
  #
  # @param _exception [IpRestrictedError]
  # @return [void]
  def ip_restricted(_exception = nil)
    render json: {
      error: {
        code: "ip_restricted",
        message: "このIPアドレスからのアクセスは許可されていません",
        your_ip: client_ip
      }
    }, status: :forbidden
  end

  # テナントのIP制限設定に基づきリクエスト元IPを検証する
  #
  # 認証済みユーザーのテナントにIP制限が設定されている場合、
  # リクエスト元IPが許可リストに含まれるかチェックする。
  # ローカルIPアドレス（::1, 127.0.0.1）の場合はスキップする
  # （本番ではリバースプロキシがX-Forwarded-For等を付与するため該当しない）。
  #
  # @return [void]
  # @raise [IpRestrictedError] IPが許可されていない場合
  def enforce_ip_restriction!
    return unless current_tenant&.ip_restriction_enabled?

    ip = client_ip
    return if loopback_ip?(ip)
    return if current_tenant.ip_allowed?(ip)

    raise IpRestrictedError
  end

  # ループバック（ローカル）IPかどうかを判定する
  #
  # @param ip [String] IPアドレス
  # @return [Boolean]
  def loopback_ip?(ip)
    IPAddr.new(ip).loopback?
  rescue IPAddr::InvalidAddressError
    false
  end
end
