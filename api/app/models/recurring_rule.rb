# frozen_string_literal: true

# 定期請求ルールモデル
#
# 定期的に請求書を自動生成するためのルールを管理する。
# 月次・四半期・年次の頻度で生成日と発行日を設定できる。
#
# @example 月次請求ルールの作成
#   RecurringRule.create!(
#     tenant: tenant,
#     customer: customer,
#     name: "月額保守費用",
#     frequency: "monthly",
#     generation_day: 25,
#     issue_day: 1,
#     is_active: true,
#     next_generation_date: Date.new(2026, 3, 25)
#   )
class RecurringRule < ApplicationRecord
  include TenantScoped

  belongs_to :tenant
  belongs_to :customer
  belongs_to :project, optional: true
  has_many :documents

  # 請求頻度の一覧
  FREQUENCIES = %w[monthly quarterly yearly].freeze

  validates :name, presence: true
  validates :frequency, inclusion: { in: FREQUENCIES }
  validates :generation_day, inclusion: { in: 1..28 }
  validates :issue_day, inclusion: { in: 1..28 }

  # @!method self.active
  #   有効なルールのみを取得するスコープ
  #   @return [ActiveRecord::Relation] is_activeがtrueのレコード
  scope :active, -> { where(is_active: true) }

  # @!method self.due_for_generation
  #   生成日が到来しているアクティブなルールを取得するスコープ
  #   @return [ActiveRecord::Relation] next_generation_dateが当日以前のアクティブなレコード
  scope :due_for_generation, -> { active.where("next_generation_date <= ?", Date.current) }
end
