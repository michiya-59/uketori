# frozen_string_literal: true

# データ移行ジョブの認可ポリシー
#
# デフォルト: admin以上がインポート操作を行える。
# カスタム権限で上書き可能。
class ImportJobPolicy < ApplicationPolicy
  # 詳細表示: デフォルトadmin以上
  #
  # @return [Boolean]
  def show?
    check_permission("import_job", "result", "admin")
  end

  # 作成: デフォルトadmin以上
  #
  # @return [Boolean]
  def create?
    check_permission("import_job", "create", "admin")
  end

  # プレビュー: デフォルトadmin以上
  #
  # @return [Boolean]
  def preview?
    check_permission("import_job", "preview", "admin")
  end

  # マッピング設定: デフォルトadmin以上
  #
  # @return [Boolean]
  def mapping?
    check_permission("import_job", "mapping", "admin")
  end

  # 実行: デフォルトadmin以上
  #
  # @return [Boolean]
  def execute?
    check_permission("import_job", "execute", "admin")
  end

  # 結果表示: デフォルトadmin以上
  #
  # @return [Boolean]
  def result?
    check_permission("import_job", "result", "admin")
  end

  # インポートジョブ一覧のスコープ
  class Scope < ApplicationPolicy::Scope
    # @return [ActiveRecord::Relation] 同一テナントのインポートジョブ
    def resolve
      scope.where(tenant_id: user.tenant_id)
    end
  end
end
