# frozen_string_literal: true

module Api
  module V1
    module Admin
      # システム管理者用アカウント発行コントローラー
      #
      # テナント＋オーナーユーザーを一括作成し、ログインアカウントを発行する。
      class AccountsController < BaseController
        # 発行済みアカウント一覧を返す
        #
        # @return [void]
        def index
          tenants = Tenant.where(deleted_at: nil)
                         .includes(:users)
                         .order(created_at: :desc)
                         .page(page_param)
                         .per(per_page_param)

          render json: {
            accounts: tenants.map { |t| serialize_account(t) },
            meta: pagination_meta(tenants)
          }
        end

        # 新規アカウント（テナント＋オーナーユーザー）を作成する
        #
        # @return [void]
        def create
          result = AuthService.sign_up(account_params)

          render json: {
            account: {
              tenant: {
                id: result[:tenant].uuid,
                name: result[:tenant].name,
                industry_type: result[:tenant].industry_type,
                plan: result[:tenant].plan
              },
              user: {
                id: result[:user].uuid,
                name: result[:user].name,
                email: result[:user].email,
                role: result[:user].role
              }
            }
          }, status: :created
        rescue AuthService::RegistrationError => e
          render json: { error: { code: "registration_error", message: e.message } },
                 status: :unprocessable_entity
        end

        # アカウント（テナント＋所属ユーザー）を論理削除する
        #
        # system_adminユーザーが所属するテナントは削除不可。
        #
        # @return [void]
        def destroy
          tenant = Tenant.where(deleted_at: nil).find_by!(uuid: params[:id])

          if tenant.users.where(deleted_at: nil, system_admin: true).exists?
            render json: { error: { code: "forbidden", message: "システム管理者が所属するアカウントは削除できません" } },
                   status: :forbidden
            return
          end

          ActiveRecord::Base.transaction do
            tenant.users.where(deleted_at: nil).find_each(&:soft_delete!)
            tenant.soft_delete!
          end

          render json: { message: "アカウントを削除しました" }
        rescue ActiveRecord::RecordNotFound
          render json: { error: { code: "not_found", message: "アカウントが見つかりません" } },
                 status: :not_found
        end

        private

        # @return [Hash]
        def account_params
          params.require(:account).permit(
            :tenant_name, :industry_code, :name, :email, :password, :password_confirmation, :plan
          )
        end

        # @return [Integer]
        def page_param
          (params[:page] || 1).to_i
        end

        # @return [Integer]
        def per_page_param
          per = (params[:per_page] || 25).to_i
          [per, 100].min
        end

        # Kaminariのページネーション結果からメタ情報を生成する
        #
        # @param collection [ActiveRecord::Relation]
        # @return [Hash]
        def pagination_meta(collection)
          {
            current_page: collection.current_page,
            total_pages: collection.total_pages,
            total_count: collection.total_count,
            per_page: collection.limit_value
          }
        end

        # テナントとオーナー情報をシリアライズする
        #
        # @param tenant [Tenant]
        # @return [Hash]
        def serialize_account(tenant)
          active_users = tenant.users.where(deleted_at: nil)
          owner = active_users.find_by(role: "owner")
          {
            id: tenant.uuid,
            tenant_name: tenant.name,
            industry_type: tenant.industry_type,
            plan: tenant.plan,
            owner_name: owner&.name,
            owner_email: owner&.email,
            users_count: active_users.count,
            has_system_admin: active_users.where(system_admin: true).exists?,
            created_at: tenant.created_at
          }
        end
      end
    end
  end
end
