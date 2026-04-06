# frozen_string_literal: true

# すべてのポリシーの基底クラス
#
# テナントスコープの検証と共通の認可ロジックを提供する。
# 各ポリシーはこのクラスを継承し、必要なアクションを許可する。
# check_permissionメソッドでカスタム権限→デフォルト権限の順にチェックする。
#
# @example ポリシーの継承
#   class CustomerPolicy < ApplicationPolicy
#     def create?
#       check_permission("customer", "create", "sales")
#     end
#   end
class ApplicationPolicy
  attr_reader :user, :record

  # @param user [User] 認証済みユーザー
  # @param record [ApplicationRecord] 認可対象のレコード
  def initialize(user, record)
    @user = user
    @record = record
  end

  # 一覧表示の許可判定
  #
  # @return [Boolean]
  def index?
    false
  end

  # 詳細表示の許可判定
  #
  # @return [Boolean]
  def show?
    false
  end

  # 作成の許可判定
  #
  # @return [Boolean]
  def create?
    false
  end

  # 更新の許可判定
  #
  # @return [Boolean]
  def update?
    false
  end

  # 削除の許可判定
  #
  # @return [Boolean]
  def destroy?
    false
  end

  # Scopeクラス: テナントスコープのレコード絞り込み
  class Scope
    attr_reader :user, :scope

    # @param user [User] 認証済みユーザー
    # @param scope [ActiveRecord::Relation] スコープ対象のリレーション
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    # スコープを解決してレコード一覧を返す
    #
    # @return [ActiveRecord::Relation]
    def resolve
      scope.all
    end
  end

  private

  # カスタム権限→デフォルト権限の順で権限をチェックする
  #
  # 1. ownerは常に全権限を持つ
  # 2. テナントにカスタム権限が設定されている場合はそれを使用
  # 3. 未設定の場合はデフォルトの最低ロールでチェック
  #
  # @param resource [String] リソース名（例: "customer"）
  # @param action [String] アクション名（例: "create"）
  # @param default_min_role [String] デフォルトの最低必要ロール（例: "sales"）
  # @return [Boolean] 許可されている場合はtrue
  def check_permission(resource, action, default_min_role)
    return true if user.owner?

    custom = lookup_custom_permission(resource, action)
    return custom unless custom.nil?

    user.has_role_at_least?(default_min_role)
  end

  # テナントのカスタム権限を検索する
  #
  # @param resource [String] リソース名
  # @param action [String] アクション名
  # @return [Boolean, nil] カスタム設定がある場合はtrue/false、未設定ならnil
  def lookup_custom_permission(resource, action)
    @role_permission = load_role_permission unless defined?(@role_permission)
    return nil unless @role_permission

    @role_permission.allowed?(resource, action)
  end

  # 現在のユーザーのロールに対応するRolePermissionを読み込む
  #
  # @return [RolePermission, nil]
  def load_role_permission
    RolePermission.find_by(tenant_id: user.tenant_id, role: user.role)
  end

  # ユーザーがowner権限を持つか判定する
  #
  # @return [Boolean]
  def owner?
    user.owner?
  end

  # ユーザーがadmin以上の権限を持つか判定する
  #
  # @return [Boolean]
  def admin_or_above?
    user.has_role_at_least?("admin")
  end

  # ユーザーがaccountant以上の権限を持つか判定する
  #
  # @return [Boolean]
  def accountant_or_above?
    user.has_role_at_least?("accountant")
  end

  # ユーザーがsales以上の権限を持つか判定する
  #
  # @return [Boolean]
  def sales_or_above?
    user.has_role_at_least?("sales")
  end
end
