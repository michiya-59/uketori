# frozen_string_literal: true

# 顧客担当者モデル
#
# 顧客に紐づく連絡先情報を管理する。
# 主担当者・請求担当者のフラグを持ち、連絡先の役割を区別できる。
#
# @example 担当者の作成
#   CustomerContact.create!(
#     customer: customer,
#     name: "田中一郎",
#     is_primary: true,
#     is_billing_contact: false
#   )
class CustomerContact < ApplicationRecord
  belongs_to :customer

  validates :name, presence: true, length: { maximum: 100 }

  # @!method self.primary
  #   主担当者を取得するスコープ
  #   @return [ActiveRecord::Relation] is_primaryがtrueのレコード
  scope :primary, -> { where(is_primary: true) }

  # @!method self.billing
  #   請求担当者を取得するスコープ
  #   @return [ActiveRecord::Relation] is_billing_contactがtrueのレコード
  scope :billing, -> { where(is_billing_contact: true) }
end
