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
        if params[:tenant].present?
          old_industry = current_tenant.industry_type
          current_tenant.update!(tenant_params)
          sync_default_products_if_industry_changed(old_industry)
        end
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

      # 業種変更時にデフォルト品目を入れ替える
      #
      # 既存のデフォルト品目（unit_priceが未設定かつユーザーが編集していないもの）を削除し、
      # 新しい業種テンプレートのデフォルト品目を追加する。
      # ユーザーが独自に追加・編集した品目は残す。
      #
      # @param old_industry [String, nil] 変更前の業種コード
      # @return [void]
      def sync_default_products_if_industry_changed(old_industry)
        new_industry = current_tenant.industry_type
        return if old_industry == new_industry

        old_template = IndustryTemplate.find_by(code: old_industry)
        new_template = IndustryTemplate.find_by(code: new_industry)
        return unless new_template

        # 旧テンプレートのデフォルト品名一覧
        old_default_names = (old_template&.default_products || []).map { |p| p["name"] }

        # 旧テンプレート由来のデフォルト品目を削除（帳票で使用中のものは残す）
        used_product_ids = DocumentItem.where(
          product_id: current_tenant.products.select(:id)
        ).pluck(:product_id).uniq

        current_tenant.products
                      .where(is_default: true)
                      .where.not(id: used_product_ids)
                      .destroy_all

        # 新テンプレートのデフォルト品目を追加（同名が既に存在しない場合のみ）
        existing_names = current_tenant.products.pluck(:name)
        (new_template.default_products || []).each do |product_data|
          next if existing_names.include?(product_data["name"])

          Product.create!(
            tenant: current_tenant,
            name: product_data["name"],
            unit: product_data["unit"],
            tax_rate_type: product_data["tax_rate_type"] || "standard",
            is_default: true
          )
        end
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
