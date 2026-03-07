# frozen_string_literal: true

module Api
  module V1
    # 入金管理コントローラー
    #
    # 入金記録の一覧取得・作成・削除を提供する。
    # 入金記録の作成・削除時にはPaymentRecordのコールバックで
    # Documentのpayment_statusが自動更新される。
    class PaymentsController < BaseController
      before_action :set_payment, only: %i[show destroy]

      # 入金記録一覧を返す
      #
      # @return [void]
      def index
        payments = policy_scope(PaymentRecord)
        payments = apply_filters(payments)
        payments = payments.includes(:document, :recorded_by_user)
                           .order(payment_date: :desc, created_at: :desc)
                           .page(page_param).per(per_page_param)

        render json: {
          payments: payments.map { |p| serialize_payment(p) },
          meta: pagination_meta(payments)
        }
      end

      # 入金記録詳細を返す
      #
      # @return [void]
      def show
        authorize @payment
        render json: { payment: serialize_payment(@payment) }
      end

      # 入金記録を作成する
      #
      # @return [void]
      def create
        authorize PaymentRecord
        document = policy_scope(Document).find_by_uuid!(params[:document_uuid])

        payment = PaymentRecord.new(payment_params.merge(
          tenant: current_tenant,
          document: document,
          recorded_by_user: current_user,
          uuid: SecureRandom.uuid
        ))
        payment.save!

        # 顧客の未回収残高を更新
        update_customer_outstanding!(document.customer)

        AuditLogger.log(
          user: current_user,
          action: "create",
          resource: payment,
          changes: { document_uuid: document.uuid, amount: payment.amount }
        )

        # 入金消込完了通知
        notify_payment_received(document, payment)

        render json: { payment: serialize_payment(payment) }, status: :created
      end

      # 入金記録を削除する
      #
      # @return [void]
      def destroy
        authorize @payment
        document = @payment.document
        @payment.destroy!

        # 顧客の未回収残高を更新
        update_customer_outstanding!(document.customer)

        AuditLogger.log(
          user: current_user,
          action: "delete",
          resource: @payment,
          changes: { document_uuid: document.uuid, amount: @payment.amount }
        )

        head :no_content
      end

      private

      # @return [void]
      def set_payment
        @payment = policy_scope(PaymentRecord).find_by_uuid!(params[:id])
      end

      # @return [ActionController::Parameters]
      def payment_params
        params.require(:payment).permit(
          :amount, :payment_date, :payment_method, :matched_by, :memo
        )
      end

      # フィルタを適用する
      #
      # @param scope [ActiveRecord::Relation]
      # @return [ActiveRecord::Relation]
      def apply_filters(scope)
        if params.dig(:filter, :document_uuid).present?
          doc = policy_scope(Document).find_by_uuid!(params[:filter][:document_uuid])
          scope = scope.where(document_id: doc.id)
        end
        if params.dig(:filter, :payment_method).present?
          scope = scope.where(payment_method: params[:filter][:payment_method])
        end
        if params.dig(:filter, :date_from).present?
          scope = scope.where("payment_date >= ?", params[:filter][:date_from])
        end
        if params.dig(:filter, :date_to).present?
          scope = scope.where("payment_date <= ?", params[:filter][:date_to])
        end
        scope
      end

      # 顧客の未回収残高を再計算して更新する
      #
      # @param customer [Customer]
      # @return [void]
      def update_customer_outstanding!(customer)
        outstanding = customer.documents.active
                              .where(document_type: "invoice")
                              .where.not(payment_status: "paid")
                              .sum(:remaining_amount)
        customer.update_columns(total_outstanding: outstanding)
      end

      # 入金消込完了通知を生成する
      #
      # @param document [Document] 対象帳票
      # @param payment [PaymentRecord] 入金記録
      # @return [void]
      def notify_payment_received(document, payment)
        current_tenant.users.active.where(role: %w[owner accountant]).find_each do |user|
          Notification.create!(
            tenant: current_tenant,
            user: user,
            notification_type: "payment_received",
            title: "入金が記録されました",
            body: "#{document.customer&.company_name}宛 #{document.document_number} への入金（#{payment.amount}円）を記録しました。"
          )
        end
      end

      # 入金記録をシリアライズする
      #
      # @param payment [PaymentRecord]
      # @return [Hash]
      def serialize_payment(payment)
        {
          id: payment.uuid,
          document_uuid: payment.document&.uuid,
          document_number: payment.document&.document_number,
          customer_name: payment.document&.customer&.company_name,
          amount: payment.amount,
          payment_date: payment.payment_date,
          payment_method: payment.payment_method,
          matched_by: payment.matched_by,
          match_confidence: payment.match_confidence,
          memo: payment.memo,
          recorded_by: payment.recorded_by_user&.name,
          created_at: payment.created_at
        }
      end
    end
  end
end
