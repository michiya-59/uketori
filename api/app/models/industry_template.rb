# frozen_string_literal: true

# 業種テンプレートマスタモデル
#
# テナントに紐づかないグローバルなマスタデータ。
# 各業種ごとの初期設定テンプレートを管理する。
#
# @example アクティブなテンプレートを取得
#   IndustryTemplate.active.ordered
class IndustryTemplate < ApplicationRecord
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true

  # @!method self.active
  #   有効なテンプレートを取得するスコープ
  #   @return [ActiveRecord::Relation] is_activeがtrueのレコード
  scope :active, -> { where(is_active: true) }

  # @!method self.ordered
  #   表示順でソートするスコープ
  #   @return [ActiveRecord::Relation] sort_order昇順のレコード
  scope :ordered, -> { order(:sort_order) }
end
