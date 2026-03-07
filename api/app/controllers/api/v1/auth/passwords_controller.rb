# frozen_string_literal: true

module Api
  module V1
    module Auth
      # パスワードリセットを処理するコントローラー
      class PasswordsController < ApplicationController
        # パスワードリセットメールを送信する
        #
        # @return [void]
        def reset
          AuthService.request_password_reset(params.dig(:auth, :email))
          render json: { message: "パスワードリセットメールを送信しました" }
        end

        # パスワードを更新する
        #
        # @return [void]
        def update
          AuthService.reset_password(
            params.dig(:auth, :token),
            params.dig(:auth, :password),
            params.dig(:auth, :password_confirmation)
          )
          render json: { message: "パスワードを更新しました" }
        rescue AuthService::AuthenticationError => e
          render json: { error: { code: "password_reset_error", message: e.message } }, status: :unprocessable_entity
        end
      end
    end
  end
end
