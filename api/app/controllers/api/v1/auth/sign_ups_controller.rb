# frozen_string_literal: true

module Api
  module V1
    module Auth
      # 新規登録を処理するコントローラー
      class SignUpsController < ApplicationController
        # テナントとオーナーユーザーを同時に作成する
        #
        # @return [void]
        def create
          result = AuthService.sign_up(sign_up_params)
          render json: {
            user: serialize_user(result[:user]),
            tenant: serialize_tenant(result[:tenant]),
            tokens: result[:tokens]
          }, status: :created
        rescue AuthService::RegistrationError => e
          render json: { error: { code: "registration_error", message: e.message } }, status: :unprocessable_entity
        end

        private

        # @return [Hash] 許可されたパラメータ
        def sign_up_params
          params.require(:auth).permit(:tenant_name, :industry_code, :name, :email, :password, :password_confirmation)
        end

        # @param user [User]
        # @return [Hash]
        def serialize_user(user)
          {
            id: user.uuid,
            name: user.name,
            email: user.email,
            role: user.role
          }
        end

        # @param tenant [Tenant]
        # @return [Hash]
        def serialize_tenant(tenant)
          {
            id: tenant.uuid,
            name: tenant.name,
            industry: tenant.industry_type,
            plan: tenant.plan
          }
        end
      end
    end
  end
end
