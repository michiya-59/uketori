# frozen_string_literal: true

# プラン制限チェッカー
#
# テナントの現在のプランに基づいてリソース制限を判定する。
# 制限超過時は PlanLimitExceededError を発生させる。
#
# @example 制限チェック
#   PlanLimitChecker.new(tenant).check!(:users)
#   PlanLimitChecker.new(tenant).check!(:documents_monthly)
class PlanLimitChecker
  # プラン別のリソース制限
  LIMITS = {
    "free" => {
      users: 1,
      documents_monthly: 5,
      customers: 10,
      ai_matching: false,
      auto_dunning: false,
      imports: 1
    },
    "starter" => {
      users: 3,
      documents_monthly: 50,
      customers: 100,
      ai_matching: true,
      auto_dunning: true,
      imports: Float::INFINITY
    },
    "standard" => {
      users: 10,
      documents_monthly: Float::INFINITY,
      customers: 500,
      ai_matching: true,
      auto_dunning: true,
      imports: Float::INFINITY
    },
    "professional" => {
      users: 30,
      documents_monthly: Float::INFINITY,
      customers: Float::INFINITY,
      ai_matching: true,
      auto_dunning: true,
      imports: Float::INFINITY
    }
  }.freeze

  # @param tenant [Tenant] チェック対象のテナント
  def initialize(tenant)
    @tenant = tenant
  end

  # 指定リソースの制限をチェックし、超過時はエラーを発生させる
  #
  # @param resource [Symbol] チェック対象リソース
  # @return [Boolean] 制限内の場合 true
  # @raise [PlanLimitExceededError] 制限超過時
  def check!(resource)
    limit = limit_for(resource)

    if limit == false
      raise PlanLimitExceededError, "#{resource}は現在のプラン（#{@tenant.plan}）ではご利用いただけません"
    end

    return true if limit == true
    return true if limit == Float::INFINITY

    current = current_count(resource)

    if current >= limit
      raise PlanLimitExceededError,
            "#{resource_label(resource)}の上限（#{limit}）に達しています。プランをアップグレードしてください。"
    end

    true
  end

  # 制限超過せずにリソースを追加可能か判定する
  #
  # @param resource [Symbol] チェック対象リソース
  # @return [Boolean] 追加可能な場合 true
  def can_add?(resource)
    check!(resource)
    true
  rescue PlanLimitExceededError
    false
  end

  # プランの制限値を返す
  #
  # @param resource [Symbol] リソース種別
  # @return [Integer, Float, Boolean] 制限値
  def limit_for(resource)
    plan_limits = LIMITS.fetch(@tenant.plan, LIMITS["free"])
    plan_limits.fetch(resource) { raise ArgumentError, "Unknown resource: #{resource}" }
  end

  # 現在のリソース使用数を返す
  #
  # @param resource [Symbol] リソース種別
  # @return [Integer] 現在の使用数
  def current_count(resource)
    case resource
    when :users
      @tenant.users.active.count
    when :documents_monthly
      @tenant.documents.active
             .where(issue_date: Date.current.beginning_of_month..Date.current.end_of_month)
             .count
    when :customers
      @tenant.customers.active.count
    when :imports
      @tenant.import_jobs.count
    else
      0
    end
  end

  private

  # リソースの日本語ラベルを返す
  #
  # @param resource [Symbol] リソース種別
  # @return [String] 日本語ラベル
  def resource_label(resource)
    case resource
    when :users then "ユーザー数"
    when :documents_monthly then "月間帳票数"
    when :customers then "顧客数"
    when :imports then "データ移行回数"
    else resource.to_s
    end
  end
end
