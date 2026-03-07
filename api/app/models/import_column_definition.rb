# frozen_string_literal: true

# インポートカラム定義モデル
#
# 外部サービスのカラム名とシステム内部のテーブル・カラム名の
# マッピング定義を管理するグローバルマスタ。
# テナントに依存せず、全テナント共通で使用される。
#
# @example カラム定義の作成
#   ImportColumnDefinition.create!(
#     source_type: "freee",
#     source_column_name: "取引先名",
#     target_table: "customers",
#     target_column: "company_name"
#   )
class ImportColumnDefinition < ApplicationRecord
  validates :source_type, presence: true
  validates :source_column_name, presence: true
  validates :target_table, presence: true
  validates :target_column, presence: true

  # @!method self.for_source(type)
  #   指定されたインポート元のカラム定義を取得するスコープ
  #   @param type [String] インポート元サービス種別
  #   @return [ActiveRecord::Relation] 指定インポート元のカラム定義
  scope :for_source, ->(type) { where(source_type: type) }
end
