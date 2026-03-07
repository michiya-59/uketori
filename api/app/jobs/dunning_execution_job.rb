# frozen_string_literal: true

# 督促実行ジョブ
#
# 毎日10:00に実行され、各テナントの督促処理を行う。
#
# @example SolidQueue recurring schedule
#   dunning_execution:
#     class: DunningExecutionJob
#     schedule: "0 10 * * *"
class DunningExecutionJob < ApplicationJob
  queue_as :default

  # @return [void]
  def perform
    Tenant.find_each do |tenant|
      next unless tenant.dunning_rules.active.exists?

      DunningExecutor.call(tenant)
    rescue StandardError => e
      Rails.logger.error("DunningExecutionJob failed for tenant #{tenant.id}: #{e.message}")
    end
  end
end
