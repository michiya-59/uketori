# frozen_string_literal: true

module Api
  module V1
    module Dunning
      # 督促ログコントローラー
      #
      # 督促実行履歴の一覧取得を提供する。
      class LogsController < BaseController
        # 督促ログ一覧を返す
        #
        # @return [void]
        def index
          logs = DunningLog.where(tenant: current_tenant)
                           .includes(:document, :customer, :dunning_rule)
                           .order(created_at: :desc)
                           .page(page_param).per(per_page_param)

          render json: {
            logs: logs.map { |l| serialize_log(l) },
            meta: pagination_meta(logs)
          }
        end

        private

        # @param log [DunningLog]
        # @return [Hash]
        def serialize_log(log)
          {
            id: log.id,
            document_number: log.document&.document_number,
            customer_name: log.customer&.company_name,
            rule_name: log.dunning_rule&.name,
            action_type: log.action_type,
            sent_to_email: log.sent_to_email,
            email_subject: log.email_subject,
            status: log.status,
            overdue_days: log.overdue_days,
            remaining_amount: log.remaining_amount,
            created_at: log.created_at
          }
        end
      end
    end
  end
end
