# frozen_string_literal: true

# マルチテナント分離を提供するConcern
#
# テナントごとのデータ分離を実現するために、
# テナントへの関連付け・バリデーション・スコープを提供する。
#
# @example モデルへの組み込み
#   class User < ApplicationRecord
#     include TenantScoped
#   end
module TenantScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :tenant

    validates :tenant_id, presence: true

    # @!method self.for_tenant(tenant)
    #   指定されたテナントに属するレコードを取得するスコープ
    #   @param tenant [Tenant, nil] フィルタ対象のテナント（nilの場合はCurrent.tenantを使用）
    #   @return [ActiveRecord::Relation] テナントでフィルタされたリレーション
    scope :for_tenant, ->(tenant = Current.tenant) { where(tenant: tenant) }
  end
end
