# frozen_string_literal: true

# データ移行ジョブの認可ポリシー
#
# admin以上がインポート操作を行える。
class ImportJobPolicy < ApplicationPolicy
  # 詳細表示: admin以上
  #
  # @return [Boolean]
  def show?
    admin_or_above?
  end

  # 作成: admin以上
  #
  # @return [Boolean]
  def create?
    admin_or_above?
  end

  # プレビュー: admin以上
  #
  # @return [Boolean]
  def preview?
    admin_or_above?
  end

  # マッピング設定: admin以上
  #
  # @return [Boolean]
  def mapping?
    admin_or_above?
  end

  # 実行: admin以上
  #
  # @return [Boolean]
  def execute?
    admin_or_above?
  end

  # 結果表示: admin以上
  #
  # @return [Boolean]
  def result?
    admin_or_above?
  end

  # インポートジョブ一覧のスコープ
  class Scope < ApplicationPolicy::Scope
    # @return [ActiveRecord::Relation] 同一テナントのインポートジョブ
    def resolve
      scope.where(tenant_id: user.tenant_id)
    end
  end
end
