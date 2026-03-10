# frozen_string_literal: true

module Api
  module V1
    module Dunning
      # 督促ルール管理コントローラー
      #
      # 督促ルールのCRUD操作を提供する。
      class RulesController < BaseController
        before_action :set_rule, only: %i[show update destroy]

        # ルール一覧を返す
        #
        # @return [void]
        def index
          rules = policy_scope(DunningRule).ordered
                                           .page(page_param).per(per_page_param)

          render json: {
            rules: rules.map { |r| serialize_rule(r) },
            meta: pagination_meta(rules)
          }
        end

        # ルール詳細を返す
        #
        # @return [void]
        def show
          authorize @rule
          render json: { rule: serialize_rule(@rule) }
        end

        # ルールを作成する
        #
        # @return [void]
        def create
          authorize DunningRule
          PlanLimitChecker.new(current_tenant).check!(:auto_dunning)
          rule = DunningRule.new(rule_params.merge(tenant: current_tenant))
          rule.save!

          render json: { rule: serialize_rule(rule) }, status: :created
        end

        # ルールを更新する
        #
        # @return [void]
        def update
          authorize @rule
          @rule.update!(rule_params)

          render json: { rule: serialize_rule(@rule) }
        end

        # ルールを削除する
        #
        # @return [void]
        def destroy
          authorize @rule
          @rule.destroy!

          head :no_content
        end

        private

        # @return [void]
        def set_rule
          @rule = policy_scope(DunningRule).find(params[:id])
        end

        # @return [ActionController::Parameters]
        def rule_params
          params.require(:rule).permit(
            :name, :trigger_days_after_due, :action_type,
            :email_template_subject, :email_template_body,
            :send_to, :custom_email, :is_active, :sort_order,
            :max_dunning_count, :interval_days
          )
        end

        # @param rule [DunningRule]
        # @return [Hash]
        def serialize_rule(rule)
          {
            id: rule.id,
            name: rule.name,
            trigger_days_after_due: rule.trigger_days_after_due,
            action_type: rule.action_type,
            email_template_subject: rule.email_template_subject,
            email_template_body: rule.email_template_body,
            send_to: rule.send_to,
            custom_email: rule.custom_email,
            is_active: rule.is_active,
            sort_order: rule.sort_order,
            max_dunning_count: rule.max_dunning_count,
            interval_days: rule.interval_days,
            created_at: rule.created_at,
            updated_at: rule.updated_at
          }
        end
      end
    end
  end
end
