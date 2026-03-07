# frozen_string_literal: true

# 与信スコア計算サービス
#
# 顧客の取引履歴から信用スコア（0-100）を計算する。
# 基準点50から加点・減点ルールで算出し、credit_score_historiesに記録する。
#
# @example
#   score = CreditScoreCalculator.call(customer)
#   score # => 75
class CreditScoreCalculator
  BASE_SCORE = 50

  class << self
    # 顧客の与信スコアを計算して更新する
    #
    # @param customer [Customer]
    # @return [Integer] 計算されたスコア
    def call(customer)
      new(customer).calculate!
    end
  end

  # @param customer [Customer]
  def initialize(customer)
    @customer = customer
    @tenant = customer.tenant
  end

  # スコアを計算して保存する
  #
  # @return [Integer]
  def calculate!
    score = BASE_SCORE
    factors = []

    # 加点ルール
    additions = calculate_additions
    additions.each do |factor|
      score += factor[:points]
      factors << factor
    end

    # 減点ルール
    subtractions = calculate_subtractions
    subtractions.each do |factor|
      score += factor[:points] # pointsは負数
      factors << factor
    end

    # 0-100にクランプ
    score = score.clamp(0, 100)

    # 履歴を記録
    @customer.credit_score_histories.create!(
      tenant: @tenant,
      score: score,
      factors: factors,
      calculated_at: Time.current
    )

    # スコア低下通知（10ポイント以上の低下）
    previous_score = @customer.credit_score || BASE_SCORE
    if score < previous_score - 10
      notify_credit_score_dropped(previous_score, score)
    end

    # 顧客のスコアを更新
    @customer.update!(
      credit_score: score,
      credit_score_updated_at: Time.current
    )

    score
  end

  private

  # 与信スコア低下通知を生成する
  #
  # @param previous_score [Integer] 変更前スコア
  # @param new_score [Integer] 変更後スコア
  # @return [void]
  def notify_credit_score_dropped(previous_score, new_score)
    @tenant.users.active.where(role: %w[owner accountant]).find_each do |user|
      Notification.create!(
        tenant: @tenant,
        user: user,
        notification_type: "credit_score_dropped",
        title: "#{@customer.company_name}の与信スコアが低下しました",
        body: "与信スコアが#{previous_score}から#{new_score}に低下しました。"
      )
    end
  end

  # 加点要素を計算する
  #
  # @return [Array<Hash>]
  def calculate_additions
    additions = []
    invoices = @customer.documents.active.where(document_type: "invoice")

    # 直近6ヶ月すべて期日内に入金: +20
    recent_invoices = invoices.where("issue_date >= ?", 6.months.ago)
                              .where.not(payment_status: "unpaid")
    if recent_invoices.any? && recent_invoices.where(payment_status: %w[overdue bad_debt]).none?
      additions << { reason: "直近6ヶ月全て期日内入金", points: 20 }
    end

    # 1年以上の取引実績: +15
    oldest = invoices.minimum(:issue_date)
    if oldest.present? && oldest < 1.year.ago
      additions << { reason: "1年以上の取引実績", points: 15 }
    end

    # 累計取引額100万円以上: +5
    total_transacted = invoices.sum(:total_amount)
    if total_transacted >= 1_000_000
      additions << { reason: "累計取引額100万円以上", points: 5 }
    end

    additions
  end

  # 減点要素を計算する
  #
  # @return [Array<Hash>]
  def calculate_subtractions
    subtractions = []
    invoices = @customer.documents.active.where(document_type: "invoice")

    # 直近3ヶ月で30日以上の遅延: -30
    severe_late = invoices.where("issue_date >= ?", 3.months.ago)
                          .where(payment_status: %w[overdue bad_debt])
                          .where("due_date < ?", 30.days.ago)
    if severe_late.exists?
      subtractions << { reason: "直近3ヶ月で30日以上遅延", points: -30 }
    end

    # 直近6ヶ月で14日以上の遅延が2回以上: -20
    moderate_late = invoices.where("issue_date >= ?", 6.months.ago)
                            .where(payment_status: %w[overdue bad_debt])
                            .where("due_date < ?", 14.days.ago)
    if moderate_late.count >= 2
      subtractions << { reason: "直近6ヶ月で14日以上遅延2回以上", points: -20 }
    end

    # 遅延率30%超: -15
    total_count = invoices.where("due_date IS NOT NULL").count
    late_count = invoices.where(payment_status: %w[overdue bad_debt]).count
    if total_count > 0 && (late_count.to_f / total_count) > 0.3
      subtractions << { reason: "遅延率30%超", points: -15 }
    end

    # 直近6ヶ月で7日以上の遅延が1回: -10
    minor_late = invoices.where("issue_date >= ?", 6.months.ago)
                         .where(payment_status: %w[overdue bad_debt])
                         .where("due_date < ?", 7.days.ago)
    if minor_late.exists? && !severe_late.exists? && moderate_late.count < 2
      subtractions << { reason: "直近6ヶ月で7日以上遅延", points: -10 }
    end

    subtractions
  end
end
