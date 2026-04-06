# frozen_string_literal: true

# ロール別権限カスタマイズモデル
#
# テナントごと・ロールごとに、デフォルト権限を上書きするカスタム設定を管理する。
# permissionsカラムにJSONB形式で "resource.action" => boolean を格納する。
#
# @example 権限のカスタマイズ
#   RolePermission.create!(
#     tenant: tenant,
#     role: "sales",
#     permissions: { "document.approve" => true, "customer.destroy" => true }
#   )
class RolePermission < ApplicationRecord
  include TenantScoped

  # 編集可能なロール（ownerは常に全権限を持つため対象外）
  EDITABLE_ROLES = %w[admin accountant sales member].freeze

  # カスタマイズ可能な権限の一覧（リソース => アクション配列）
  CUSTOMIZABLE_PERMISSIONS = {
    "customer" => %w[create update destroy credit_history verify_invoice_number],
    "product" => %w[create update destroy],
    "project" => %w[create update destroy status],
    "document" => %w[create update destroy duplicate convert approve reject send_document lock bulk_generate ai_suggest],
    "payment_record" => %w[create destroy],
    "bank_statement" => %w[import ocr_preview match ai_match ai_suggest],
    "dunning_rule" => %w[create update destroy execute],
    "user" => %w[create invite update destroy],
    "tenant" => %w[update],
    "import_job" => %w[create preview mapping execute result]
  }.freeze

  # デフォルトの最低必要ロール（"resource.action" => ロール名）
  DEFAULT_MIN_ROLES = {
    "customer.create" => "sales",
    "customer.update" => "sales",
    "customer.destroy" => "admin",
    "customer.credit_history" => "accountant",
    "customer.verify_invoice_number" => "sales",
    "product.create" => "accountant",
    "product.update" => "accountant",
    "product.destroy" => "admin",
    "project.create" => "sales",
    "project.update" => "sales",
    "project.destroy" => "admin",
    "project.status" => "sales",
    "document.create" => "sales",
    "document.update" => "sales",
    "document.destroy" => "admin",
    "document.duplicate" => "sales",
    "document.convert" => "sales",
    "document.approve" => "accountant",
    "document.reject" => "accountant",
    "document.send_document" => "sales",
    "document.lock" => "accountant",
    "document.bulk_generate" => "accountant",
    "document.ai_suggest" => "sales",
    "payment_record.create" => "accountant",
    "payment_record.destroy" => "admin",
    "bank_statement.import" => "accountant",
    "bank_statement.ocr_preview" => "accountant",
    "bank_statement.match" => "accountant",
    "bank_statement.ai_match" => "accountant",
    "bank_statement.ai_suggest" => "accountant",
    "dunning_rule.create" => "accountant",
    "dunning_rule.update" => "accountant",
    "dunning_rule.destroy" => "admin",
    "dunning_rule.execute" => "accountant",
    "user.create" => "admin",
    "user.invite" => "admin",
    "user.update" => "admin",
    "user.destroy" => "admin",
    "tenant.update" => "admin",
    "import_job.create" => "admin",
    "import_job.preview" => "admin",
    "import_job.mapping" => "admin",
    "import_job.execute" => "admin",
    "import_job.result" => "admin"
  }.freeze

  # リソースの日本語ラベル
  RESOURCE_LABELS = {
    "customer" => "顧客",
    "product" => "品目マスタ",
    "project" => "案件",
    "document" => "帳票",
    "payment_record" => "入金",
    "bank_statement" => "銀行明細",
    "dunning_rule" => "督促ルール",
    "user" => "ユーザー",
    "tenant" => "テナント設定",
    "import_job" => "データインポート"
  }.freeze

  # アクションの日本語ラベル
  ACTION_LABELS = {
    "create" => "作成",
    "update" => "更新",
    "destroy" => "削除",
    "credit_history" => "信用履歴の閲覧",
    "verify_invoice_number" => "インボイス番号検証",
    "status" => "ステータス変更",
    "duplicate" => "複製",
    "convert" => "帳票変換",
    "approve" => "承認",
    "reject" => "却下",
    "send_document" => "送付",
    "lock" => "ロック（確定）",
    "bulk_generate" => "一括生成",
    "ai_suggest" => "AI提案",
    "import" => "インポート",
    "ocr_preview" => "OCRプレビュー",
    "match" => "手動マッチング",
    "ai_match" => "AI自動マッチング",
    "execute" => "実行",
    "invite" => "招待",
    "preview" => "プレビュー",
    "mapping" => "マッピング設定",
    "result" => "結果表示"
  }.freeze

  validates :role, presence: true, inclusion: { in: EDITABLE_ROLES }
  validates :role, uniqueness: { scope: :tenant_id }
  validate :validate_permission_keys
  validate :validate_permission_values

  # 指定リソース・アクションのカスタム権限を返す
  #
  # @param resource [String] リソース名
  # @param action [String] アクション名
  # @return [Boolean, nil] カスタム設定がある場合はtrue/false、未設定ならnil
  def allowed?(resource, action)
    key = "#{resource}.#{action}"
    return nil unless permissions.key?(key)

    permissions[key] == true
  end

  # 指定リソース・アクションがデフォルトのロールで許可されているかを返す
  #
  # @param role [String] ロール名
  # @param resource [String] リソース名
  # @param action [String] アクション名
  # @return [Boolean]
  def self.default_allowed?(role, resource, action)
    key = "#{resource}.#{action}"
    min_role = DEFAULT_MIN_ROLES[key]
    return false unless min_role

    role_index = User::ROLES.index(role)
    min_index = User::ROLES.index(min_role)
    return false if role_index.nil? || min_index.nil?

    role_index <= min_index
  end

  # 全権限キーの一覧を返す
  #
  # @return [Array<String>] "resource.action" 形式の配列
  def self.all_permission_keys
    DEFAULT_MIN_ROLES.keys
  end

  # カスタマイズ可能な権限キーかを判定する
  #
  # @param key [String] "resource.action" 形式のキー
  # @return [Boolean]
  def self.valid_permission_key?(key)
    resource, action = key.split(".", 2)
    CUSTOMIZABLE_PERMISSIONS[resource]&.include?(action) || false
  end

  private

  # permissionsのキーが有効な権限キーかバリデーションする
  #
  # @return [void]
  def validate_permission_keys
    return if permissions.blank?

    permissions.each_key do |key|
      unless self.class.valid_permission_key?(key)
        errors.add(:permissions, "#{key} は無効な権限キーです")
      end
    end
  end

  # permissionsの値がboolean型かバリデーションする
  #
  # @return [void]
  def validate_permission_values
    return if permissions.blank?

    permissions.each do |key, value|
      unless [true, false].include?(value)
        errors.add(:permissions, "#{key} の値はtrue/falseである必要があります")
      end
    end
  end
end
