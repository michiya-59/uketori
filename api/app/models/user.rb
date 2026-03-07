# frozen_string_literal: true

# ユーザーモデル
#
# テナントに所属するユーザーを管理する。
# 認証にはhas_secure_passwordを使用し、ロールベースのアクセス制御を提供する。
#
# @example ユーザーの作成
#   User.create!(
#     tenant: tenant,
#     name: "山田太郎",
#     email: "yamada@example.com",
#     password: "secure_password",
#     role: "admin"
#   )
class User < ApplicationRecord
  include TenantScoped
  include UuidFindable
  include SoftDeletable

  has_secure_password

  # 利用可能なロール一覧（権限の高い順）
  ROLES = %w[owner admin accountant sales member].freeze

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { maximum: 100 }
  validates :role, inclusion: { in: ROLES }
  validates :jti, presence: true, uniqueness: true

  before_validation -> { self.jti ||= SecureRandom.uuid }, on: :create

  # @!method self.by_role(role)
  #   指定されたロールのユーザーを取得するスコープ
  #   @param role [String] フィルタ対象のロール
  #   @return [ActiveRecord::Relation] 指定ロールのユーザー
  scope :by_role, ->(role) { where(role: role) }

  # ユーザーがownerロールかを判定する
  #
  # @return [Boolean] ownerの場合はtrue
  def owner?
    role == "owner"
  end

  # ユーザーがadminロールかを判定する
  #
  # @return [Boolean] adminの場合はtrue
  def admin?
    role == "admin"
  end

  # ユーザーがaccountantロールかを判定する
  #
  # @return [Boolean] accountantの場合はtrue
  def accountant?
    role == "accountant"
  end

  # ユーザーがsalesロールかを判定する
  #
  # @return [Boolean] salesの場合はtrue
  def sales?
    role == "sales"
  end

  # ユーザーがmemberロールかを判定する
  #
  # @return [Boolean] memberの場合はtrue
  def member?
    role == "member"
  end

  # 指定された最低ロール以上の権限を持つかを判定する
  #
  # ROLESの配列インデックスが小さいほど権限が高い。
  # ユーザーのロールインデックスが指定ロールインデックス以下であれば
  # 十分な権限を持つと判定する。
  #
  # @param min_role [String] 必要な最低ロール（ROLES配列に含まれる値）
  # @return [Boolean] 指定ロール以上の権限を持つ場合はtrue
  # @raise [ArgumentError] 無効なロールが指定された場合
  #
  # @example
  #   user.role # => "admin"
  #   user.has_role_at_least?("accountant") # => true
  #   user.has_role_at_least?("owner")      # => false
  def has_role_at_least?(min_role)
    user_index = ROLES.index(role)
    min_index = ROLES.index(min_role)

    raise ArgumentError, "Invalid role: #{min_role}" if min_index.nil?

    return false if user_index.nil?

    user_index <= min_index
  end
end
