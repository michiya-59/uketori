# frozen_string_literal: true

# UUIDによるレコード検索機能を提供するConcern
#
# 主キー（id）の代わりにUUIDでレコードを検索する機能を提供する。
# 外部公開用のAPIなどでidを露出させたくない場合に使用する。
#
# @example モデルへの組み込み
#   class Tenant < ApplicationRecord
#     include UuidFindable
#   end
#
# @example UUIDによる検索
#   Tenant.find_by_uuid!("550e8400-e29b-41d4-a716-446655440000")
module UuidFindable
  extend ActiveSupport::Concern

  class_methods do
    # UUIDでレコードを検索する
    #
    # 指定されたUUIDに一致するレコードを返す。
    # 見つからない場合はActiveRecord::RecordNotFoundを発生させる。
    #
    # @param uuid [String] 検索対象のUUID
    # @return [ApplicationRecord] UUIDに一致するレコード
    # @raise [ActiveRecord::RecordNotFound] レコードが見つからない場合
    def find_by_uuid!(uuid)
      find_by!(uuid: uuid)
    end
  end
end
