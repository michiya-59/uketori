# frozen_string_literal: true

# 監査ログを記録するサービス
#
# 全CUD操作の監査証跡をaudit_logsテーブルに記録する。
# 電子帳簿保存法対応のための操作履歴管理を行う。
#
# @example
#   AuditLogger.log(user: current_user, action: "create", resource: document, details: { status: "draft" })
class AuditLogger
  class << self
    # 監査ログを記録する
    #
    # @param user [User] 操作ユーザー
    # @param action [String] 操作種別（create, update, delete, send, lock等）
    # @param resource [ApplicationRecord] 対象リソース
    # @param changes [Hash] 変更データ
    # @param request [ActionDispatch::Request, nil] HTTPリクエスト（IP/UA記録用）
    # @return [AuditLog] 作成されたログレコード
    def log(user:, action:, resource:, changes: {}, request: nil)
      resource_type = resource.class.name.underscore
      attrs = {
        tenant: user.tenant,
        user: user,
        action: action,
        resource_type: resource_type,
        resource_id: resource.id,
        changes_data: changes.merge(
          resource_uuid: resource.try(:uuid),
          timestamp: Time.current.iso8601
        )
      }
      if request
        attrs[:ip_address] = request.remote_ip
        attrs[:user_agent] = request.user_agent&.truncate(500)
      end
      AuditLog.create!(attrs)
    end
  end
end
