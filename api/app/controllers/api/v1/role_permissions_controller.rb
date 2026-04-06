# frozen_string_literal: true

module Api
  module V1
    # ロール別権限設定コントローラー
    #
    # テナント内のロールごとのカスタム権限を管理する。
    # owner/admin以上のみアクセス可能。
    class RolePermissionsController < BaseController
      # 全ロールの権限設定を返す
      #
      # カスタム設定がないロールにはデフォルト値を返す。
      #
      # @return [void]
      def index
        authorize :role_permission, :index?

        existing = RolePermission.where(tenant_id: current_tenant.id)
                                 .index_by(&:role)

        roles_data = RolePermission::EDITABLE_ROLES.map do |role|
          build_role_response(role, existing[role])
        end

        render json: {
          roles: roles_data,
          resources: build_resources_metadata
        }
      end

      # 指定ロールの権限を更新する
      #
      # @return [void]
      def update
        role = params[:id]
        unless RolePermission::EDITABLE_ROLES.include?(role)
          render json: { error: { code: "invalid_role", message: "無効なロールです" } },
                 status: :unprocessable_entity
          return
        end

        authorize role, :update?, policy_class: RolePermissionPolicy

        role_permission = RolePermission.find_or_initialize_by(
          tenant_id: current_tenant.id,
          role: role
        )
        role_permission.permissions = permission_params
        role_permission.save!

        render json: { role_permission: build_role_response(role, role_permission) }
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: { code: "validation_error", message: e.record.errors.full_messages.join(", ") } },
               status: :unprocessable_entity
      end

      # 指定ロールの権限をデフォルトにリセットする
      #
      # @return [void]
      def reset
        role = params[:id]
        unless RolePermission::EDITABLE_ROLES.include?(role)
          render json: { error: { code: "invalid_role", message: "無効なロールです" } },
                 status: :unprocessable_entity
          return
        end

        authorize role, :reset?, policy_class: RolePermissionPolicy

        RolePermission.where(tenant_id: current_tenant.id, role: role).destroy_all

        render json: { role_permission: build_role_response(role, nil) }
      end

      private

      # @return [Hash] パーミッションのハッシュ
      def permission_params
        raw = params.require(:permissions).permit!.to_h
        raw.transform_values { |v| ActiveModel::Type::Boolean.new.cast(v) }
      end

      # ロールの権限レスポンスを組み立てる
      #
      # @param role [String] ロール名
      # @param role_permission [RolePermission, nil] カスタム設定
      # @return [Hash]
      def build_role_response(role, role_permission)
        permissions = RolePermission.all_permission_keys.each_with_object({}) do |key, hash|
          default_allowed = RolePermission.default_allowed?(role, *key.split(".", 2))
          custom_value = role_permission&.allowed?(*key.split(".", 2))

          hash[key] = {
            allowed: custom_value.nil? ? default_allowed : custom_value,
            default: default_allowed,
            customized: !custom_value.nil?
          }
        end

        {
          role: role,
          role_label: role_label(role),
          permissions: permissions
        }
      end

      # リソースのメタデータを返す（フロントでの表示用）
      #
      # @return [Array<Hash>]
      def build_resources_metadata
        RolePermission::CUSTOMIZABLE_PERMISSIONS.map do |resource, actions|
          {
            resource: resource,
            resource_label: RolePermission::RESOURCE_LABELS[resource] || resource,
            actions: actions.map do |action|
              {
                action: action,
                action_label: RolePermission::ACTION_LABELS[action] || action,
                key: "#{resource}.#{action}",
                default_min_role: RolePermission::DEFAULT_MIN_ROLES["#{resource}.#{action}"],
                default_min_role_label: role_label(RolePermission::DEFAULT_MIN_ROLES["#{resource}.#{action}"])
              }
            end
          }
        end
      end

      # ロール名の日本語ラベルを返す
      #
      # @param role [String] ロール名
      # @return [String]
      def role_label(role)
        {
          "owner" => "オーナー",
          "admin" => "管理者",
          "accountant" => "経理",
          "sales" => "営業",
          "member" => "メンバー"
        }[role] || role.to_s
      end
    end
  end
end
