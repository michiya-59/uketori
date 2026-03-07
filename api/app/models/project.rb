# frozen_string_literal: true

# 案件モデル
#
# テナントの案件（プロジェクト）を管理する。
# 見積から入金完了までのステータス遷移を制御し、
# 関連する書類（見積書・請求書等）を紐付ける。
#
# @example 案件の作成
#   Project.create!(
#     tenant: tenant,
#     customer: customer,
#     name: "Webサイト構築案件",
#     project_number: "PJ-2026-001",
#     status: "negotiation"
#   )
class Project < ApplicationRecord
  include TenantScoped
  include UuidFindable
  include SoftDeletable

  belongs_to :tenant
  belongs_to :customer
  belongs_to :assigned_user, class_name: "User", optional: true
  has_many :documents

  # 案件ステータスの一覧
  STATUSES = %w[negotiation won lost in_progress delivered invoiced paid partially_paid overdue bad_debt cancelled].freeze

  # ステータス遷移の許可マップ
  TRANSITIONS = {
    "negotiation" => %w[won lost],
    "won" => %w[in_progress cancelled],
    "in_progress" => %w[delivered cancelled],
    "delivered" => %w[invoiced],
    "invoiced" => %w[paid partially_paid overdue],
    "partially_paid" => %w[paid overdue],
    "overdue" => %w[paid partially_paid bad_debt],
    "bad_debt" => %w[paid],
    "lost" => %w[negotiation],
    "cancelled" => []
  }.freeze

  validates :name, presence: true, length: { maximum: 255 }
  validates :project_number, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :probability, numericality: { in: 0..100 }, allow_nil: true

  # ステータスを遷移させる
  #
  # 現在のステータスから指定されたステータスへの遷移が許可されている場合に
  # ステータスを更新する。許可されていない場合はエラーを発生させる。
  #
  # @param new_status [String] 遷移先のステータス（STATUSESに含まれる値）
  # @return [Boolean] 更新に成功した場合はtrue
  # @raise [ActiveRecord::RecordInvalid] ステータス遷移が許可されていない場合
  def transition_to!(new_status)
    unless can_transition_to?(new_status)
      errors.add(:status, "を'#{status}'から'#{new_status}'に変更することはできません")
      raise ActiveRecord::RecordInvalid, self
    end

    update!(status: new_status)
  end

  # 指定されたステータスへの遷移が可能かを判定する
  #
  # @param new_status [String] 遷移先のステータス
  # @return [Boolean] 遷移が可能な場合はtrue
  def can_transition_to?(new_status)
    allowed = TRANSITIONS.fetch(status, [])
    allowed.include?(new_status)
  end
end
