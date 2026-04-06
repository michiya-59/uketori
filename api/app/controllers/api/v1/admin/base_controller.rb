# frozen_string_literal: true

module Api
  module V1
    module Admin
      # システム管理者用APIのベースコントローラー
      #
      # users.system_admin カラムが true のユーザーのみアクセス可能。
      class BaseController < ApplicationController
        before_action :authenticate_user!
        before_action :enforce_ip_restriction!
        before_action :require_system_admin!

        private

        # システム管理者かどうかを検証する
        #
        # @return [void]
        def require_system_admin!
          unless current_user&.system_admin?
            render json: { error: { code: "forbidden", message: "システム管理者権限が必要です" } },
                   status: :forbidden
          end
        end
      end
    end
  end
end
