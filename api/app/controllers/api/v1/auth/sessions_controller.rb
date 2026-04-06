# frozen_string_literal: true

module Api
  module V1
    module Auth
      # ログイン・ログアウト・トークンリフレッシュを処理するコントローラー
      class SessionsController < ApplicationController
        before_action :authenticate_user!, only: [:destroy]

        # メールアドレスとパスワードで認証しトークンペアを返す
        #
        # 認証成功後、ユーザーが所属するテナントにIP制限が設定されている場合、
        # リクエスト元IPが許可リストに含まれるかチェックする。
        #
        # @return [void]
        def create
          result = AuthService.sign_in(params.dig(:auth, :email), params.dig(:auth, :password))

          # ログイン成功後にテナントのIP制限をチェック
          # ローカルIP（::1, 127.0.0.1）の場合はスキップ
          tenant = result[:user].tenant
          ip = client_ip
          if tenant.ip_restriction_enabled? && !loopback_ip?(ip) && !tenant.ip_allowed?(ip)
            raise IpRestrictedError
          end

          render json: {
            user: {
              id: result[:user].uuid,
              name: result[:user].name,
              email: result[:user].email,
              role: result[:user].role
            },
            tokens: result[:tokens]
          }
        rescue AuthService::AuthenticationError => e
          render json: { error: { code: "authentication_error", message: e.message } }, status: :unauthorized
        end

        # 現在のユーザーのトークンを無効化する
        #
        # @return [void]
        def destroy
          AuthService.sign_out(current_user)
          head :no_content
        end

        # リフレッシュトークンを使って新しいトークンペアを発行する
        #
        # @return [void]
        def refresh
          tokens = AuthService.refresh(params[:refresh_token])
          if tokens
            render json: { tokens: tokens }
          else
            render json: { error: { code: "invalid_refresh_token", message: "Invalid or expired refresh token" } }, status: :unauthorized
          end
        end
      end
    end
  end
end
