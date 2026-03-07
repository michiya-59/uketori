# frozen_string_literal: true

# 論理削除機能を提供するConcern
#
# deleted_atカラムを使用してレコードの論理削除・復元を行う。
# 物理削除を行わずにレコードを非アクティブにできる。
#
# @example モデルへの組み込み
#   class User < ApplicationRecord
#     include SoftDeletable
#   end
#
# @example 論理削除と復元
#   user.soft_delete!
#   user.soft_deleted? # => true
#   user.restore!
#   user.soft_deleted? # => false
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    # @!method self.active
    #   論理削除されていないレコードを取得するスコープ
    #   @return [ActiveRecord::Relation] deleted_atがnilのレコード
    scope :active, -> { where(deleted_at: nil) }

    # @!method self.deleted
    #   論理削除済みのレコードを取得するスコープ
    #   @return [ActiveRecord::Relation] deleted_atが設定されているレコード
    scope :deleted, -> { where.not(deleted_at: nil) }
  end

  # レコードを論理削除する
  #
  # deleted_atに現在時刻を設定してレコードを保存する。
  #
  # @return [Boolean] 更新に成功した場合はtrue
  # @raise [ActiveRecord::RecordInvalid] バリデーションエラー時
  def soft_delete!
    update!(deleted_at: Time.current)
  end

  # 論理削除されたレコードを復元する
  #
  # deleted_atをnilに設定してレコードを保存する。
  #
  # @return [Boolean] 更新に成功した場合はtrue
  # @raise [ActiveRecord::RecordInvalid] バリデーションエラー時
  def restore!
    update!(deleted_at: nil)
  end

  # レコードが論理削除されているかを判定する
  #
  # @return [Boolean] 論理削除されている場合はtrue
  def soft_deleted?
    deleted_at.present?
  end
end
