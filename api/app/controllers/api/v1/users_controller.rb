# frozen_string_literal: true

module Api
  module V1
    # ユーザー管理を行うコントローラー
    #
    # 同一テナント内のユーザーのCRUDと招待機能を提供する。
    class UsersController < BaseController
      before_action :set_user, only: %i[show update destroy]

      # テナント内のユーザー一覧を返す
      #
      # @return [void]
      def index
        users = policy_scope(User)
                  .active
                  .order(created_at: :desc)
                  .page(page_param)
                  .per(per_page_param)

        render json: {
          users: users.map { |u| serialize_user(u) },
          meta: pagination_meta(users)
        }
      end

      # 指定ユーザーの詳細を返す
      #
      # @return [void]
      def show
        authorize @user
        render json: { user: serialize_user_detail(@user) }
      end

      # 新規ユーザーを作成する
      #
      # @return [void]
      def create
        authorize User
        user = User.new(user_params.merge(tenant: current_tenant, password: SecureRandom.hex(16)))
        user.save!

        render json: { user: serialize_user(user) }, status: :created
      end

      # ユーザー情報を更新する
      #
      # @return [void]
      def update
        authorize @user
        @user.update!(user_update_params)
        render json: { user: serialize_user(@user) }
      end

      # ユーザーを論理削除する
      #
      # @return [void]
      def destroy
        authorize @user
        @user.update!(deleted_at: Time.current)
        head :no_content
      end

      # ユーザーを招待する
      #
      # @return [void]
      def invite
        authorize User
        user = AuthService.invite_user(current_user, invite_params)
        render json: { user: serialize_user(user) }, status: :created
      rescue AuthService::PlanLimitError => e
        render json: { error: { code: "plan_limit_error", message: e.message } }, status: :forbidden
      rescue AuthService::RegistrationError => e
        render json: { error: { code: "invitation_error", message: e.message } }, status: :unprocessable_entity
      end

      private

      # @return [void]
      def set_user
        @user = policy_scope(User).active.find_by!(uuid: params[:id])
      end

      # @return [ActionController::Parameters]
      def user_params
        params.require(:user).permit(:name, :email, :role)
      end

      # @return [ActionController::Parameters]
      def user_update_params
        params.require(:user).permit(:name, :email, :role)
      end

      # @return [ActionController::Parameters]
      def invite_params
        params.require(:user).permit(:name, :email, :role)
      end

      # @param user [User]
      # @return [Hash] ユーザーの基本情報
      def serialize_user(user)
        {
          id: user.uuid,
          name: user.name,
          email: user.email,
          role: user.role,
          created_at: user.created_at
        }
      end

      # @param user [User]
      # @return [Hash] ユーザーの詳細情報
      def serialize_user_detail(user)
        {
          id: user.uuid,
          name: user.name,
          email: user.email,
          role: user.role,
          last_sign_in_at: user.last_sign_in_at,
          sign_in_count: user.sign_in_count,
          created_at: user.created_at,
          updated_at: user.updated_at
        }
      end
    end
  end
end
