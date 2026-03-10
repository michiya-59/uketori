# frozen_string_literal: true

module Api
  module V1
    module Admin
      # システム管理者の認証確認コントローラー
      #
      # 現在のユーザーがシステム管理者かどうかを返す。
      class MeController < BaseController
        # システム管理者の認証情報を返す
        #
        # @return [void]
        def show
          render json: {
            admin: true,
            email: current_user.email,
            name: current_user.name
          }
        end
      end
    end
  end
end
