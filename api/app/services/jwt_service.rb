# frozen_string_literal: true

# JWT トークンの生成・検証・リフレッシュを行うサービス
#
# アクセストークンとリフレッシュトークンの2種類を管理する。
# アクセストークンは短命（デフォルト15分）、リフレッシュトークンは長命（デフォルト7日）。
#
# @example トークンペアの生成
#   tokens = JwtService.encode(user)
#   # => { access_token: "...", refresh_token: "...", expires_in: 900 }
#
# @example トークンのデコード
#   payload = JwtService.decode(token)
#   # => { "sub" => 1, "tenant_id" => 1, "jti" => "...", "type" => "access", ... }
class JwtService
  ALGORITHM = "HS256"
  ACCESS_TOKEN_TYPE = "access"
  REFRESH_TOKEN_TYPE = "refresh"

  class << self
    # ユーザーに対してアクセストークンとリフレッシュトークンのペアを生成する
    #
    # @param user [User] トークンを発行する対象ユーザー
    # @return [Hash] access_token, refresh_token, expires_in を含むハッシュ
    # @raise [ArgumentError] ユーザーが nil の場合
    def encode(user)
      raise ArgumentError, "User is required" if user.nil?

      now = Time.current.to_i

      access_token = generate_token(
        sub: user.id,
        tenant_id: user.tenant_id,
        role: user.role,
        jti: user.jti,
        type: ACCESS_TOKEN_TYPE,
        iat: now,
        exp: now + access_token_expiration
      )

      refresh_token = generate_token(
        sub: user.id,
        tenant_id: user.tenant_id,
        jti: user.jti,
        type: REFRESH_TOKEN_TYPE,
        iat: now,
        exp: now + refresh_token_expiration
      )

      {
        access_token: access_token,
        refresh_token: refresh_token,
        expires_in: access_token_expiration
      }
    end

    # トークンをデコードして検証済みのペイロードを返す
    #
    # @param token [String] JWTトークン文字列
    # @return [HashWithIndifferentAccess] デコードされたペイロード
    # @raise [JWT::DecodeError] トークンが無効な場合
    # @raise [JWT::ExpiredSignature] トークンの有効期限が切れている場合
    def decode(token)
      decoded = JWT.decode(
        token,
        secret_key,
        true,
        { algorithm: ALGORITHM }
      )
      ActiveSupport::HashWithIndifferentAccess.new(decoded.first)
    end

    # リフレッシュトークンを使って新しいトークンペアを生成する
    #
    # リフレッシュトークンを検証し、ユーザーのjtiが一致することを確認した上で
    # 新しいトークンペアを発行する。jtiが一致しない場合はトークンが無効化された
    # とみなしnilを返す。
    #
    # @param refresh_token [String] リフレッシュトークン文字列
    # @return [Hash, nil] 新しいトークンペア、または無効な場合はnil
    def refresh(refresh_token)
      payload = decode(refresh_token)

      return nil unless payload[:type] == REFRESH_TOKEN_TYPE

      user = User.find_by(id: payload[:sub])
      return nil if user.nil?
      return nil if user.jti != payload[:jti]

      encode(user)
    rescue JWT::DecodeError, JWT::ExpiredSignature
      nil
    end

    # トークンからユーザーを検索して返す
    #
    # アクセストークンをデコードし、ペイロードの情報を使って
    # ユーザーを検索する。jtiの一致も確認する（ログアウト検知）。
    #
    # @param token [String] アクセストークン文字列
    # @return [User, nil] 認証されたユーザー、または無効な場合はnil
    def authenticate(token)
      payload = decode(token)

      return nil unless payload[:type] == ACCESS_TOKEN_TYPE

      user = User.find_by(id: payload[:sub])
      return nil if user.nil?
      return nil if user.jti != payload[:jti]
      return nil if user.deleted_at.present?

      user
    rescue JWT::DecodeError, JWT::ExpiredSignature
      nil
    end

    # ユーザーのjtiをリセットしてすべてのトークンを無効化する
    #
    # @param user [User] トークンを無効化するユーザー
    # @return [Boolean] 更新成功の場合true
    def revoke(user)
      user.update!(jti: SecureRandom.uuid)
    end

    private

    # @return [String] JWT署名に使用するシークレットキー
    def secret_key
      ENV.fetch("JWT_SECRET") { Rails.application.secret_key_base }
    end

    # @return [Integer] アクセストークンの有効期限（秒）
    def access_token_expiration
      ENV.fetch("JWT_EXPIRATION", 900).to_i
    end

    # @return [Integer] リフレッシュトークンの有効期限（秒）
    def refresh_token_expiration
      ENV.fetch("JWT_REFRESH_EXPIRATION", 604_800).to_i
    end

    # ペイロードからJWTトークンを生成する
    #
    # @param payload [Hash] トークンに含めるペイロード
    # @return [String] エンコードされたJWTトークン
    def generate_token(payload)
      JWT.encode(payload, secret_key, ALGORITHM)
    end
  end
end
