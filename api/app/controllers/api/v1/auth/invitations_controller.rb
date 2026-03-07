# frozen_string_literal: true

module Api
  module V1
    module Auth
      # 招待受諾を処理するコントローラー
      class InvitationsController < ApplicationController
        # 招待トークンを使ってアカウントをアクティベートする
        #
        # @return [void]
        def accept
          result = AuthService.accept_invitation(
            params.dig(:auth, :token),
            {
              password: params.dig(:auth, :password),
              password_confirmation: params.dig(:auth, :password_confirmation)
            }
          )
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
          render json: { error: { code: "invitation_error", message: e.message } }, status: :unprocessable_entity
        end
      end
    end
  end
end
