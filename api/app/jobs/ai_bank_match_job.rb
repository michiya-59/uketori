# frozen_string_literal: true

# AI銀行明細マッチングジョブ
#
# BankStatementImporterでインポート後に非同期でマッチングを実行する。
#
# @example
#   AiBankMatchJob.perform_later(tenant.id, batch_id, user.id)
class AiBankMatchJob < ApplicationJob
  queue_as :default

  # @param tenant_id [Integer] テナントID
  # @param batch_id [String] インポートバッチID
  # @param user_id [Integer] 実行ユーザーID
  # @return [void]
  def perform(tenant_id, batch_id, user_id)
    tenant = Tenant.find(tenant_id)
    user = User.find(user_id)

    AiBankMatcher.call(tenant, batch_id, user: user)
  end
end
