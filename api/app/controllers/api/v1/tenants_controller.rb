# frozen_string_literal: true

module Api
  module V1
    # テナント設定を管理するコントローラー
    #
    # 現在のテナントの情報表示・更新を行う。
    # 会社情報・住所・振込先・帳票設定など全設定項目を管理する。
    class TenantsController < BaseController
      # テナント情報を返す
      #
      # @return [void]
      def show
        authorize current_tenant, policy_class: TenantPolicy
        render json: { tenant: serialize_tenant(current_tenant) }
      end

      # テナント設定を更新する
      #
      # @return [void]
      def update
        authorize current_tenant, policy_class: TenantPolicy
        current_tenant.update!(tenant_params) if params[:tenant].present?
        render json: { tenant: serialize_tenant(current_tenant) }
      end

      private

      # @return [ActionController::Parameters]
      def tenant_params
        params.require(:tenant).permit(
          # 基本情報
          :name, :name_kana,
          # 住所
          :postal_code, :prefecture, :city, :address_line1, :address_line2,
          # 連絡先
          :phone, :fax, :email, :website,
          # インボイス
          :invoice_registration_number,
          # 振込先
          :bank_name, :bank_branch_name,
          :bank_account_type, :bank_account_number, :bank_account_holder,
          # 業種・設定
          :industry_type, :fiscal_year_start_month, :timezone,
          # 帳票設定
          :document_sequence_format, :default_payment_terms_days, :default_tax_rate,
          # 督促
          :dunning_enabled
        )
      end

      # @param tenant [Tenant]
      # @return [Hash] テナント情報のシリアライズ
      def serialize_tenant(tenant)
        {
          id: tenant.uuid,
          # 基本情報
          name: tenant.name,
          name_kana: tenant.name_kana,
          # 住所
          postal_code: tenant.postal_code,
          prefecture: tenant.prefecture,
          city: tenant.city,
          address_line1: tenant.address_line1,
          address_line2: tenant.address_line2,
          # 連絡先
          phone: tenant.phone,
          fax: tenant.fax,
          email: tenant.email,
          website: tenant.website,
          # インボイス
          invoice_registration_number: tenant.invoice_registration_number,
          invoice_number_verified: tenant.invoice_number_verified,
          # 振込先
          bank_name: tenant.bank_name,
          bank_branch_name: tenant.bank_branch_name,
          bank_account_type: tenant.bank_account_type,
          bank_account_number: tenant.bank_account_number,
          bank_account_holder: tenant.bank_account_holder,
          # 業種・設定
          plan: tenant.plan,
          industry_type: tenant.industry_type,
          fiscal_year_start_month: tenant.fiscal_year_start_month,
          timezone: tenant.timezone,
          # 帳票設定
          document_sequence_format: tenant.document_sequence_format,
          default_payment_terms_days: tenant.default_payment_terms_days,
          default_tax_rate: tenant.default_tax_rate,
          # 督促
          dunning_enabled: tenant.dunning_enabled,
          # 機能フラグ
          import_enabled: tenant.import_enabled,
          # メタ
          created_at: tenant.created_at,
          updated_at: tenant.updated_at
        }
      end
    end
  end
end
