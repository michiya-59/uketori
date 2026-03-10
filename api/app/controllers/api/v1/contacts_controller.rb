# frozen_string_literal: true

module Api
  module V1
    # お問い合わせコントローラー
    #
    # システム不具合報告、機能要望、プラン変更などのお問い合わせを受け付ける。
    class ContactsController < BaseController
      # お問い合わせカテゴリ一覧
      CATEGORIES = %w[bug feature_request plan_inquiry billing account data_issue security other].freeze

      # お問い合わせ優先度一覧
      PRIORITIES = %w[low normal high urgent].freeze

      # プランアップグレードお問い合わせを送信する
      #
      # @return [void]
      def plan_inquiry
        desired_plan = params[:desired_plan]
        message = params[:message]

        unless desired_plan.present? && message.present?
          return render json: { error: { code: "validation_error", message: "希望プランとお問い合わせ内容は必須です" } },
                        status: :unprocessable_entity
        end

        ContactMailer.plan_inquiry(
          tenant: current_tenant,
          user: current_user,
          desired_plan: desired_plan,
          message: message
        ).deliver_later

        render json: { message: "お問い合わせを送信しました" }, status: :created
      end

      # 汎用お問い合わせを送信する
      #
      # @return [void]
      def create
        category = params[:category]
        subject = params[:subject]
        body = params[:body]
        priority = params[:priority] || "normal"
        page_url = params[:page_url]
        user_agent = request.user_agent

        errors = []
        errors << "カテゴリを選択してください" unless category.present? && CATEGORIES.include?(category)
        errors << "件名を入力してください" unless subject.present?
        errors << "お問い合わせ内容を入力してください" unless body.present?
        errors << "優先度が不正です" unless PRIORITIES.include?(priority)

        if errors.any?
          return render json: { error: { code: "validation_error", message: errors.join("、") } },
                        status: :unprocessable_entity
        end

        ContactMailer.general_inquiry(
          tenant: current_tenant,
          user: current_user,
          category: category,
          subject: subject,
          body: body,
          priority: priority,
          page_url: page_url,
          user_agent: user_agent
        ).deliver_later

        AuditLogger.log(
          user: current_user,
          action: "create",
          resource: current_tenant,
          changes: { contact_category: category, contact_subject: subject }
        )

        render json: { message: "お問い合わせを送信しました。サポートチームより折り返しご連絡いたします。" }, status: :created
      end
    end
  end
end
