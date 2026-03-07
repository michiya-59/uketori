# frozen_string_literal: true

# 監査ログモデル
#
# システム操作の監査証跡を記録する。
# ユーザーの操作（作成・更新・削除・送信等）をリソース種別ごとに記録し、
# コンプライアンス対応や不正検知に利用する。
#
# @example 監査ログの作成
#   AuditLog.create!(
#     tenant: tenant,
#     user: user,
#     action: "create",
#     resource_type: "document",
#     resource_id: document.id
#   )
class AuditLog < ApplicationRecord
  include TenantScoped

  belongs_to :tenant
  belongs_to :user, optional: true

  # 操作種別の一覧
  ACTIONS = %w[create update delete send lock import export login match execute].freeze

  # リソース種別の一覧
  RESOURCE_TYPES = %w[document customer project payment payment_record bank_statement dunning_rule dunning_log user setting tenant import_job notification].freeze

  validates :action, inclusion: { in: ACTIONS }
  validates :resource_type, inclusion: { in: RESOURCE_TYPES }
end
