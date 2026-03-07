# frozen_string_literal: true

module Api
  module V1
    module Dunning
      # 督促実行コントローラー
      #
      # 手動での督促一括実行を提供する。
      class ExecutionsController < BaseController
        # 手動で督促を実行する
        #
        # @return [void]
        def create
          authorize DunningRule, :create?

          result = DunningExecutor.call(current_tenant)

          render json: result
        end
      end
    end
  end
end
