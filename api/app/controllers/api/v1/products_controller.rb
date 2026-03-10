# frozen_string_literal: true

module Api
  module V1
    # 品目マスタを管理するコントローラー
    #
    # 品目のCRUD操作と有効/無効フィルタ・ソート機能を提供する。
    class ProductsController < BaseController
      before_action :set_product, only: %i[show update destroy]

      # 品目一覧を返す
      #
      # @return [void]
      def index
        products = policy_scope(Product)
        products = products.active if params.dig(:filter, :active) != "false"
        products = products.ordered.page(page_param).per(per_page_param)

        render json: {
          products: products.map { |p| serialize_product(p) },
          meta: pagination_meta(products)
        }
      end

      # 品目詳細を返す
      #
      # @return [void]
      def show
        authorize @product
        render json: { product: serialize_product(@product) }
      end

      # 品目を新規作成する
      #
      # @return [void]
      def create
        authorize Product
        product = Product.new(product_params.merge(tenant: current_tenant))
        product.save!

        render json: { product: serialize_product(product) }, status: :created
      end

      # 品目情報を更新する
      #
      # デフォルト品目の更新は許可しない。
      # @return [void]
      def update
        authorize @product
        if @product.default?
          render json: { error: { message: "デフォルト品目は編集できません" } }, status: :forbidden
          return
        end
        @product.update!(product_params)

        render json: { product: serialize_product(@product) }
      end

      # 品目を削除する
      #
      # デフォルト品目の削除は許可しない。
      # @return [void]
      def destroy
        authorize @product
        if @product.default?
          render json: { error: { message: "デフォルト品目は削除できません" } }, status: :forbidden
          return
        end
        @product.destroy!

        head :no_content
      end

      private

      # @return [void]
      def set_product
        @product = policy_scope(Product).find(params[:id])
      end

      # @return [ActionController::Parameters]
      def product_params
        params.require(:product).permit(
          :code, :name, :description, :unit, :unit_price,
          :tax_rate, :tax_rate_type, :category, :sort_order, :is_active
        )
      end

      # @param product [Product]
      # @return [Hash] 品目情報
      def serialize_product(product)
        {
          id: product.id,
          code: product.code,
          name: product.name,
          description: product.description,
          unit: product.unit,
          unit_price: product.unit_price,
          tax_rate: product.tax_rate,
          tax_rate_type: product.tax_rate_type,
          category: product.category,
          sort_order: product.sort_order,
          is_active: product.is_active,
          is_default: product.is_default,
          created_at: product.created_at
        }
      end
    end
  end
end
