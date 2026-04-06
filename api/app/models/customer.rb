# frozen_string_literal: true

# 顧客モデル
#
# テナントに所属する取引先（顧客・仕入先）を管理する。
# 信用スコアや支払い状況のトラッキングを提供する。
#
# @example 顧客の作成
#   Customer.create!(
#     tenant: tenant,
#     company_name: "株式会社取引先",
#     customer_type: "client",
#     credit_score: 80
#   )
class Customer < ApplicationRecord
  include TenantScoped
  include UuidFindable
  include SoftDeletable

  belongs_to :tenant
  has_many :customer_contacts, dependent: :destroy
  has_many :projects
  has_many :documents
  has_many :credit_score_histories

  # 顧客区分の一覧
  TYPES = %w[client vendor both].freeze

  validates :company_name, presence: true, length: { maximum: 255 }
  validates :company_name_kana, format: { with: /\A[ァ-ヶー　\s]+\z/, message: "カタカナで入力してください" },
                                length: { maximum: 255 },
                                allow_blank: true
  validates :customer_type, inclusion: { in: TYPES }
  validates :credit_score, numericality: { in: 0..100 }, allow_nil: true

  # @!method self.search_by_name(query)
  #   会社名・会社名カナで部分一致検索するスコープ
  #   @param query [String] 検索クエリ文字列
  #   @return [ActiveRecord::Relation] 会社名が一致するレコード
  scope :search_by_name, lambda { |query|
    escaped = "%#{sanitize_sql_like(query)}%"
    where("company_name LIKE :query OR company_name_kana LIKE :query", query: escaped)
  }

  # @!method self.with_overdue
  #   支払い期限超過の請求を持つ顧客を取得するスコープ
  #   @return [ActiveRecord::Relation] 未払いの請求がある顧客
  scope :with_overdue, -> { where(has_overdue: true) }
  scope :with_any_tags, ->(tags) { where("tags ?| array[:tags]", tags: tags) }
  scope :with_outstanding_at_least, ->(amount) { where("total_outstanding >= ?", amount) }

  # @!method self.high_risk(threshold)
  #   信用スコアが閾値以下の高リスク顧客を取得するスコープ
  #   @param threshold [Integer] 信用スコアの閾値（デフォルト: 30）
  #   @return [ActiveRecord::Relation] 高リスク顧客
  scope :high_risk, ->(threshold = 30) { where("credit_score <= ?", threshold) }

  # @!method self.ordered_by_outstanding
  #   未回収残高の降順で並べるスコープ
  #   @return [ActiveRecord::Relation] 未回収残高降順のレコード
  scope :ordered_by_outstanding, -> { order(outstanding_balance: :desc) }

  after_commit :enqueue_invoice_number_verification, if: :invoice_registration_number_previously_changed?

  private

  # 適格番号が変更された場合に検証ジョブをキューに追加する
  #
  # @return [void]
  def enqueue_invoice_number_verification
    return if invoice_registration_number.blank?

    InvoiceNumberVerificationJob.perform_later("Customer", id)
  end
end
