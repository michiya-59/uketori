# frozen_string_literal: true

# 通知の認可ポリシー
#
# ユーザーは自分宛の通知のみ閲覧・更新できる。
class NotificationPolicy < ApplicationPolicy
  # 一覧表示: 自分の通知のみ
  #
  # @return [Boolean]
  def index?
    true
  end

  # 更新（既読化）: 自分の通知のみ
  #
  # @return [Boolean]
  def update?
    record.user_id == user.id
  end

  # 通知一覧のスコープ
  class Scope < ApplicationPolicy::Scope
    # @return [ActiveRecord::Relation] 自分宛の通知
    def resolve
      scope.where(user_id: user.id)
    end
  end
end
