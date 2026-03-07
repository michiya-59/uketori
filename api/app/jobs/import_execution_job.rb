# frozen_string_literal: true

# データインポート実行ジョブ
#
# SolidQueueで非同期にImportExecutorを実行する。
# 完了/失敗時にNotificationを生成して通知する。
#
# @example
#   ImportExecutionJob.perform_later(import_job.id)
class ImportExecutionJob < ApplicationJob
  queue_as :default

  # インポートジョブを実行する
  #
  # @param import_job_id [Integer] ImportJobのID
  # @return [void]
  def perform(import_job_id)
    import_job = ImportJob.find(import_job_id)

    result = ImportExecutor.call(import_job)

    # 完了通知を作成
    Notification.create!(
      tenant: import_job.tenant,
      user: import_job.user,
      notification_type: "import_completed",
      title: "データインポートが完了しました",
      body: "成功: #{result[:success]}件 / スキップ: #{result[:skipped]}件 / エラー: #{result[:error]}件",
      data: { import_job_uuid: import_job.uuid }
    )
  rescue StandardError => e
    Rails.logger.error("ImportExecutionJob failed: #{e.message}")

    import_job = ImportJob.find_by(id: import_job_id)
    return unless import_job

    Notification.create!(
      tenant: import_job.tenant,
      user: import_job.user,
      notification_type: "import_failed",
      title: "データインポートが失敗しました",
      body: e.message,
      data: { import_job_uuid: import_job.uuid }
    )
  end
end
