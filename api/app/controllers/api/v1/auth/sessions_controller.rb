# frozen_string_literal: true

module Api
  module V1
    module Auth
      # ログイン・ログアウト・トークンリフレッシュを処理するコントローラー
      class SessionsController < ApplicationController
        before_action :authenticate_user!, only: [:destroy]

        # メールアドレスとパスワードで認証しトークンペアを返す
        #
        # @return [void]
        def create
          result = AuthService.sign_in(params.dig(:auth, :email), params.dig(:auth, :password))
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
