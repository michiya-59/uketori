# frozen_string_literal: true

# すべてのポリシーの基底クラス
#
# テナントスコープの検証と共通の認可ロジックを提供する。
# 各ポリシーはこのクラスを継承し、必要なアクションを許可する。
#
# @example ポリシーの継承
#   class CustomerPolicy < ApplicationPolicy
#     def show?
#       true
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
