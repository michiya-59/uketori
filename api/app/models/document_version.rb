# frozen_string_literal: true

# 書類バージョンモデル
#
# 書類の変更履歴をスナップショットとして管理する。
# 変更者と変更内容（JSON）を記録し、過去バージョンへの参照を可能にする。
#
# @example バージョンの作成
#   DocumentVersion.create!(
#     document: document,
#     changed_by_user: user,
#     version: 1,
#     snapshot: document.attributes.to_json
#   )
class DocumentVersion < ApplicationRecord
  belongs_to :document
  belongs_to :changed_by_user, class_name: "User"

  validates :version, presence: true, numericality: { greater_than: 0 }
  validates :snapshot, presence: true
end
