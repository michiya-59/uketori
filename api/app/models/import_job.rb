# frozen_string_literal: true

# インポートジョブモデル
#
# 外部サービス（board・freee・misoca等）やCSV/Excelからの
# データインポート処理の状態を管理する。
#
# @example インポートジョブの作成
#   ImportJob.create!(
#     tenant: tenant,
#     user: user,
#     source_type: "freee",
#     status: "pending",
#     file_url: "https://storage.example.com/imports/data.csv",
#     file_name: "data.csv",
#     file_size: 1024
#   )
class ImportJob < ApplicationRecord
  include TenantScoped
  include UuidFindable

  belongs_to :tenant
  belongs_to :user

  # インポート元サービスの一覧
  SOURCES = %w[board freee misoca makeleaps excel csv_generic].freeze

  # ジョブステータスの一覧
  STATUSES = %w[pending parsing mapping previewing importing completed failed].freeze

  validates :source_type, inclusion: { in: SOURCES }
  validates :status, inclusion: { in: STATUSES }
  validates :file_url, presence: true
  validates :file_name, presence: true
  validates :file_size, presence: true, numericality: { greater_than: 0 }
end
