# frozen_string_literal: true

module Api
  module V1
    # API v1 の全コントローラーのベースクラス
    #
    # 認証を要求し、テナントスコープの適用とページネーションのヘルパーを提供する。
    class BaseController < ApplicationController
      before_action :authenticate_user!

      private

      # Kaminariのページネーション結果からメタ情報を生成する
      #
      # @param collection [Kaminari::PaginatableArray, ActiveRecord::Relation] ページネーション済みコレクション
      # @return [Hash] ページネーションメタ情報
      def pagination_meta(collection)
        {
          current_page: collection.current_page,
          total_pages: collection.total_pages,
          total_count: collection.total_count,
          per_page: collection.limit_value
        }
      end

      # パラメータからページ番号を取得する
      #
      # @return [Integer] ページ番号（デフォルト: 1）
      def page_param
        (params[:page] || 1).to_i
      end

      # パラメータから1ページあたりの件数を取得する
      #
      # @return [Integer] 件数（デフォルト: 25、最大: 100）
      def per_page_param
        per = (params[:per_page] || 25).to_i
        [per, 100].min
      end
    end
  end
end
