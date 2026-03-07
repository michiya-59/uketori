# frozen_string_literal: true

# 認証関連のメール送信を行うメーラー
class AuthMailer < ApplicationMailer
  # パスワードリセットメールを送信する
  #
  # @param user [User] パスワードリセット対象のユーザー
  # @param token [String] パスワードリセットトークン
  # @return [Mail::Message]
  def password_reset(user, token)
    @user = user
    @token = token
    @reset_url = "#{frontend_url}/password/reset?token=#{token}"

    mail(
      to: user.email,
      subject: "【ウケトリ】パスワードリセットのご案内"
    )
  end

  # 招待メールを送信する
  #
  # @param user [User] 招待されたユーザー
  # @param inviter [User] 招待したユーザー
  # @return [Mail::Message]
  def invitation(user, inviter)
    @user = user
    @inviter = inviter
    @tenant = inviter.tenant
    @accept_url = "#{frontend_url}/invitation/accept?token=#{user.invitation_token}"

    mail(
      to: user.email,
      subject: "【ウケトリ】#{@tenant.name}への招待"
    )
  end

  private

  # @return [String] フロントエンドのURL
  def frontend_url
    ENV.fetch("FRONTEND_URL", "http://localhost:4101")
  end
end
