# frozen_string_literal: true

module Api
  module V1
    # 業種テンプレートの一覧・詳細を提供するコントローラー
    #
    # グローバルマスタデータのため認証不要で参照可能。
    # サインアップ時の業種選択や設定画面での参照に使用する。
    class IndustryTemplatesController < ApplicationController
      # 有効な業種テンプレート一覧を返す
      #
      # @return [void]
      def index
        templates = IndustryTemplate.active.ordered
        render json: {
          industry_templates: templates.map { |t| serialize_template(t) }
        }
      end

      # 指定コードの業種テンプレート詳細を返す
      #
      # @return [void]
      def show
        template = IndustryTemplate.find_by!(code: params[:id])
        render json: { industry_template: serialize_template_detail(template) }
      end

      private

      # @param template [IndustryTemplate]
      # @return [Hash] テンプレートの基本情報
      def serialize_template(template)
        {
          code: template.code,
          name: template.name,
          sort_order: template.sort_order
        }
      end

      # @param template [IndustryTemplate]
      # @return [Hash] テンプレートの詳細情報
      def serialize_template_detail(template)
        {
          code: template.code,
          name: template.name,
          labels: template.labels,
          default_products: template.default_products,
          default_statuses: template.default_statuses,
          tax_settings: template.tax_settings,
          sort_order: template.sort_order
        }
      end
    end
  end
end
