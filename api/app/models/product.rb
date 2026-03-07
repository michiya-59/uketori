# frozen_string_literal: true

# 商品マスタモデル
#
# テナントで利用する商品・サービスの情報を管理する。
# 見積書・請求書の明細行で参照される。
#
# @example 商品の作成
#   Product.create!(
#     tenant: tenant,
#     name: "コンサルティングサービス",
#     tax_rate_type: "standard",
#     unit_price: 50_000,
#     is_active: true
#   )
class Product < ApplicationRecord
  include TenantScoped

  belongs_to :tenant

  validates :name, presence: true, length: { maximum: 255 }
  validates :tax_rate_type, inclusion: { in: %w[standard reduced exempt] }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # @!method self.active
  #   有効な商品のみを取得するスコープ
  #   @return [ActiveRecord::Relation] is_activeがtrueのレコード
  scope :active, -> { where(is_active: true) }

  # @!method self.ordered
  #   表示順で並べるスコープ
  #   @return [ActiveRecord::Relation] sort_order昇順のレコード
  scope :ordered, -> { order(:sort_order) }
end
