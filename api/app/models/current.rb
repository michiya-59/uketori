# frozen_string_literal: true

# リクエストスコープの現在のコンテキストを管理するクラス
#
# マルチテナント環境において、現在のテナントとユーザーを
# リクエスト単位で保持するために使用する。
#
# @example テナントとユーザーの設定
#   Current.tenant = tenant
#   Current.user = user
#
# @see https://api.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html
class Current < ActiveSupport::CurrentAttributes
  # @!attribute [rw] tenant
  #   @return [Tenant, nil] 現在のリクエストに紐づくテナント
  # @!attribute [rw] user
  #   @return [User, nil] 現在のリクエストに紐づくユーザー
  attribute :tenant, :user
end
