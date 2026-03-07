# frozen_string_literal: true

# 通知モデル
#
# ユーザーへの通知（支払い期限、ステータス変更等）を管理する。
# 未読・既読のステータスと既読日時を保持する。
#
# @example 通知の作成
#   Notification.create!(
#     tenant: tenant,
#     user: user,
#     notification_type: "payment_overdue",
#     title: "請求書 INV-2026-001 の支払い期限が超過しています"
#   )
class Notification < ApplicationRecord
  include TenantScoped

  belongs_to :tenant
  belongs_to :user

  validates :notification_type, presence: true
  validates :title, presence: true

  # @!method self.unread
  #   未読通知のみを取得するスコープ
  #   @return [ActiveRecord::Relation] is_readがfalseのレコード
  scope :unread, -> { where(is_read: false) }

  # @!method self.recent
  #   作成日時の降順で並べるスコープ
  #   @return [ActiveRecord::Relation] created_at降順のレコード
  scope :recent, -> { order(created_at: :desc) }

  # 通知を既読にする
  #
  # is_readをtrueに、read_atに現在時刻を設定して保存する。
  #
  # @return [Boolean] 更新に成功した場合はtrue
  # @raise [ActiveRecord::RecordInvalid] バリデーションエラー時
  def mark_as_read!
    update!(is_read: true, read_at: Time.current)
  end
end
