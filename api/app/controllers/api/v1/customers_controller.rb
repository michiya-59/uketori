# frozen_string_literal: true

module Api
  module V1
    # 顧客マスタを管理するコントローラー
    #
    # 顧客のCRUD操作、担当者管理、適格番号検証、与信スコア履歴の
    # 参照機能を提供する。
    class CustomersController < BaseController
      before_action :set_customer, only: %i[show update destroy documents credit_history verify_invoice_number]

      # 顧客一覧を返す
      #
      # @return [void]
      def index
        customers = policy_scope(Customer).active
        customers = apply_filters(customers)
        customers = apply_sort(customers)
        customers = customers.page(page_param).per(per_page_param)

        render json: {
          customers: customers.map { |c| serialize_customer(c) },
          meta: pagination_meta(customers)
        }
      end

      # 顧客詳細を返す
      #
      # @return [void]
      def show
        authorize @customer
        render json: {
          customer: serialize_customer_detail(@customer)
        }
      end

      # 顧客を新規作成する
      #
      # @return [void]
      def create
        authorize Customer
        PlanLimitChecker.new(current_tenant).check!(:customers)
        customer = Customer.new(customer_params.merge(tenant: current_tenant))
        customer.save!

        render json: { customer: serialize_customer(customer) }, status: :created
      end

      # 顧客情報を更新する
      #
      # @return [void]
      def update
        authorize @customer
        @customer.update!(customer_params)

        render json: { customer: serialize_customer(@customer) }
      end

      # 顧客を論理削除する
      #
      # @return [void]
      def destroy
        authorize @customer
        @customer.soft_delete!

        head :no_content
      end

      # 顧客に紐づく帳票一覧を返す
      #
      # @return [void]
      def documents
        authorize @customer
        docs = @customer.documents.active
                        .order(issue_date: :desc)
                        .page(page_param).per(per_page_param)

        render json: {
          documents: docs.map { |d| serialize_document_summary(d) },
          meta: pagination_meta(docs)
        }
      end

      # 顧客の与信スコア履歴を返す
      #
      # @return [void]
      def credit_history
        authorize @customer
        histories = @customer.credit_score_histories
                             .order(calculated_at: :desc)
                             .page(page_param).per(per_page_param)

        render json: {
          credit_history: histories.map { |h| serialize_credit_history(h) },
          meta: pagination_meta(histories)
        }
      end

      # 顧客の適格請求書発行事業者番号を検証する
      #
      # @return [void]
      def verify_invoice_number
        authorize @customer
        unless @customer.invoice_registration_number.present?
          return render json: { error: { code: "validation_error", message: "適格番号が設定されていません" } },
                        status: :unprocessable_entity
        end

        InvoiceNumberVerificationJob.perform_later("Customer", @customer.id)
        render json: { message: "適格番号の検証を開始しました" }
      end

      private

      # @return [void]
      def set_customer
        @customer = policy_scope(Customer).active.find_by_uuid!(params[:id])
      end

      # @return [ActionController::Parameters]
      def customer_params
        params.require(:customer).permit(
          :company_name, :company_name_kana, :customer_type,
          :department, :title, :contact_name,
          :email, :phone, :fax,
          :postal_code, :prefecture, :city, :address_line1, :address_line2,
          :invoice_registration_number,
          :payment_terms_days, :default_tax_rate,
          :bank_name, :bank_branch_name, :bank_account_type,
          :bank_account_number, :bank_account_holder,
          :memo, tags: []
        )
      end

      # @param scope [ActiveRecord::Relation]
      # @return [ActiveRecord::Relation] フィルタ適用済みのスコープ
      def apply_filters(scope)
        scope = scope.search_by_name(params.dig(:filter, :q)) if params.dig(:filter, :q).present?
        scope = scope.where(customer_type: params.dig(:filter, :customer_type)) if params.dig(:filter, :customer_type).present?
        if params.dig(:filter, :credit_score_min).present?
          scope = scope.where("credit_score >= ?", params.dig(:filter, :credit_score_min).to_i)
        end
        if params.dig(:filter, :credit_score_max).present?
          scope = scope.where("credit_score <= ?", params.dig(:filter, :credit_score_max).to_i)
        end
        scope = scope.with_overdue if params.dig(:filter, :has_overdue) == "true"
        scope
      end

      # @param scope [ActiveRecord::Relation]
      # @return [ActiveRecord::Relation] ソート適用済みのスコープ
      def apply_sort(scope)
        sort_column = %w[company_name created_at credit_score total_outstanding].include?(params[:sort]) ? params[:sort] : "created_at"
        sort_order = params[:order] == "asc" ? :asc : :desc
        scope.order(sort_column => sort_order)
      end

      # @param customer [Customer]
      # @return [Hash] 顧客の基本情報
      def serialize_customer(customer)
        {
          id: customer.uuid,
          company_name: customer.company_name,
          company_name_kana: customer.company_name_kana,
          customer_type: customer.customer_type,
          contact_name: customer.contact_name,
          email: customer.email,
          phone: customer.phone,
          credit_score: customer.credit_score,
          total_outstanding: customer.total_outstanding,
          tags: customer.tags,
          created_at: customer.created_at
        }
      end

      # @param customer [Customer]
      # @return [Hash] 顧客の詳細情報
      def serialize_customer_detail(customer)
        serialize_customer(customer).merge(
          department: customer.department,
          title: customer.title,
          fax: customer.fax,
          postal_code: customer.postal_code,
          prefecture: customer.prefecture,
          city: customer.city,
          address_line1: customer.address_line1,
          address_line2: customer.address_line2,
          invoice_registration_number: customer.invoice_registration_number,
          invoice_number_verified: customer.invoice_number_verified,
          payment_terms_days: customer.payment_terms_days,
          default_tax_rate: customer.default_tax_rate,
          bank_name: customer.bank_name,
          bank_branch_name: customer.bank_branch_name,
          bank_account_type: customer.bank_account_type,
          bank_account_number: customer.bank_account_number,
          bank_account_holder: customer.bank_account_holder,
          memo: customer.memo,
          avg_payment_days: customer.avg_payment_days,
          late_payment_rate: customer.late_payment_rate,
          contacts: customer.customer_contacts.map { |c| serialize_contact(c) },
          updated_at: customer.updated_at
        )
      end

      # @param contact [CustomerContact]
      # @return [Hash] 担当者情報
      def serialize_contact(contact)
        {
          id: contact.id,
          name: contact.name,
          email: contact.email,
          phone: contact.phone,
          department: contact.department,
          title: contact.title,
          is_primary: contact.is_primary,
          is_billing_contact: contact.is_billing_contact
        }
      end

      # @param doc [Document]
      # @return [Hash] 帳票サマリー情報
      def serialize_document_summary(doc)
        {
          id: doc.uuid,
          document_type: doc.document_type,
          document_number: doc.document_number,
          status: doc.status,
          total_amount: doc.total_amount,
          issue_date: doc.issue_date,
          due_date: doc.due_date,
          payment_status: doc.payment_status
        }
      end

      # @param history [CreditScoreHistory]
      # @return [Hash] 与信スコア履歴
      def serialize_credit_history(history)
        {
          id: history.id,
          score: history.score,
          factors: history.factors,
          calculated_at: history.calculated_at
        }
      end
    end
  end
end
