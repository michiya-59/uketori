# frozen_string_literal: true

# 督促ログモデル
#
# 督促アクション（メール送信・社内アラート）の実行履歴を記録する。
# 送信状態（送信済み・失敗・開封・クリック）をトラッキングする。
#
# @example 督促ログの作成
#   DunningLog.create!(
#     tenant: tenant,
#     document: document,
#     dunning_rule: dunning_rule,
#     customer: customer,
#     action_type: "email",
#     status: "sent",
#     overdue_days: 7,
#     remaining_amount: 100_000
#   )
class DunningLog < ApplicationRecord
  include TenantScoped

  belongs_to :tenant
  belongs_to :document
  belongs_to :dunning_rule
  belongs_to :customer

  validates :action_type, presence: true
  validates :status, inclusion: { in: %w[sent failed opened clicked] }
  validates :overdue_days, presence: true
  validates :remaining_amount, presence: true
end
