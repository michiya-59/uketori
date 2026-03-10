# frozen_string_literal: true

module Api
  module V1
    module Admin
      # システム管理者用テナント管理コントローラー
      #
      # テナント一覧の表示、プラン変更、各種フラグの変更を提供する。
      class TenantsController < BaseController
        before_action :set_tenant, only: %i[show update]

        # テナント一覧を返す
        #
        # @return [void]
        def index
          tenants = Tenant.where(deleted_at: nil).order(created_at: :desc)

          if params[:search].present?
            tenants = tenants.where("name ILIKE ?", "%#{params[:search]}%")
          end
          if params[:plan].present?
            tenants = tenants.where(plan: params[:plan])
          end

          tenants = tenants.page(page_param).per(per_page_param)

          render json: {
            tenants: tenants.map { |t| serialize_tenant(t) },
            meta: pagination_meta(tenants)
          }
        end

        # テナント詳細を返す
        #
        # @return [void]
        def show
          render json: { tenant: serialize_tenant_detail(@tenant) }
        end

        # テナントを更新する
        #
        # @return [void]
        def update
          @tenant.update!(tenant_params)
          render json: { tenant: serialize_tenant_detail(@tenant) }
        end

        private

        # @return [void]
        def set_tenant
          @tenant = Tenant.find_by_uuid!(params[:id])
        end

        # @return [ActionController::Parameters]
        def tenant_params
          params.require(:tenant).permit(
            :plan, :import_enabled, :dunning_enabled
          )
        end

        # ページ番号を取得する
        #
        # @return [Integer]
        def page_param
          (params[:page] || 1).to_i
        end

        # 1ページあたりの件数を取得する
        #
        # @return [Integer]
        def per_page_param
          per = (params[:per_page] || 25).to_i
          [per, 100].min
        end

        # Kaminariのページネーション結果からメタ情報を生成する
        #
        # @param collection [ActiveRecord::Relation]
        # @return [Hash]
        def pagination_meta(collection)
          {
            current_page: collection.current_page,
            total_pages: collection.total_pages,
            total_count: collection.total_count,
            per_page: collection.limit_value
          }
        end

        # テナントのサマリーを返す
        #
        # @param tenant [Tenant]
        # @return [Hash]
        def serialize_tenant(tenant)
          {
            id: tenant.uuid,
            name: tenant.name,
            plan: tenant.plan,
            import_enabled: tenant.import_enabled,
            dunning_enabled: tenant.dunning_enabled,
            users_count: tenant.users.where(deleted_at: nil).count,
            customers_count: tenant.customers.where(deleted_at: nil).count,
            documents_count: tenant.documents.where(deleted_at: nil).count,
            created_at: tenant.created_at,
            updated_at: tenant.updated_at
          }
        end

        # テナントの詳細を返す
        #
        # @param tenant [Tenant]
        # @return [Hash]
        def serialize_tenant_detail(tenant)
          serialize_tenant(tenant).merge(
            email: tenant.email,
            phone: tenant.phone,
            industry_type: tenant.industry_type,
            plan_started_at: tenant.plan_started_at,
            invoice_registration_number: tenant.invoice_registration_number,
            invoice_number_verified: tenant.invoice_number_verified,
            owner: tenant.users.where(deleted_at: nil).find_by(role: "owner")&.then { |u|
              { name: u.name, email: u.email }
            }
          )
        end
      end
    end
  end
end
