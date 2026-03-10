# frozen_string_literal: true

module Api
  module V1
    module Admin
      # システム管理者用APIのベースコントローラー
      #
      # ADMIN_EMAILS環境変数に含まれるメールアドレスのユーザーのみアクセス可能。
      class BaseController < ApplicationController
        before_action :authenticate_user!
        before_action :require_system_admin!

        private

        # システム管理者かどうかを検証する
        #
        # @return [void]
        def require_system_admin!
          unless system_admin?
            render json: { error: { code: "forbidden", message: "システム管理者権限が必要です" } },
                   status: :forbidden
          end
        end

        # 現在のユーザーがシステム管理者かどうかを判定する
        #
        # @return [Boolean] システム管理者の場合 true
        def system_admin?
          admin_emails = ENV.fetch("ADMIN_EMAILS", "").split(",").map(&:strip)
          admin_emails.include?(current_user&.email)
        end
      end
    end
  end
end
