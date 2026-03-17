# frozen_string_literal: true

require "anthropic"

# AI取引先分析サービス
#
# 顧客の取引データ・支払い傾向・与信スコアを総合的に分析し、
# Claude AIによるインサイト・リスク評価・アクション推奨を生成する。
#
# @example
#   result = AiCustomerAnalyzer.call(customer)
#   result[:summary]         # => "A社は安定した取引先です..."
#   result[:risk_assessment] # => "low"
class AiCustomerAnalyzer
  class << self
    # 顧客分析を実行する
    #
    # @param customer [Customer] 分析対象の顧客
    # @return [Hash] 分析結果
    def call(customer)
      new(customer).analyze!
    end
  end

  # @param customer [Customer] 分析対象の顧客
  def initialize(customer)
    @customer = customer
    @tenant = customer.tenant
  end

  # 分析を実行する
  #
  # @return [Hash]
  def analyze!
    stats = gather_statistics
    payment_history = gather_payment_history
    ai_analysis = generate_ai_analysis(stats, payment_history)

    {
      customer_id: @customer.uuid,
      company_name: @customer.company_name,
      statistics: stats,
      payment_history: payment_history,
      credit_score: @customer.credit_score,
      credit_score_trend: credit_score_trend,
      risk_assessment: ai_analysis[:risk_assessment],
      summary: ai_analysis[:summary],
      recommendations: ai_analysis[:recommendations],
      confidence: ai_analysis[:confidence]
    }
  rescue StandardError => e
    Rails.logger.warn("AiCustomerAnalyzer error: #{e.message}")
    fallback_result
  end

  private

  # 取引統計を集計する
  #
  # @return [Hash]
  def gather_statistics
    invoices = @customer.documents.active.where(document_type: "invoice")

    total_invoiced = invoices.sum(:total_amount)
    total_paid = invoices.sum(:paid_amount)
    invoice_count = invoices.count
    overdue_count = invoices.where(payment_status: %w[overdue bad_debt]).count

    # 期間別集計
    last_6m = invoices.where("issue_date >= ?", 6.months.ago)
    last_12m = invoices.where("issue_date >= ?", 12.months.ago)

    {
      total_invoiced: total_invoiced,
      total_paid: total_paid,
      total_outstanding: @customer.total_outstanding,
      invoice_count: invoice_count,
      overdue_count: overdue_count,
      overdue_rate: invoice_count > 0 ? (overdue_count.to_f / invoice_count * 100).round(1) : 0.0,
      avg_payment_days: @customer.avg_payment_days&.to_f&.round(1) || 0.0,
      late_payment_rate: @customer.late_payment_rate&.to_f&.round(1) || 0.0,
      last_6m_invoiced: last_6m.sum(:total_amount),
      last_6m_count: last_6m.count,
      last_12m_invoiced: last_12m.sum(:total_amount),
      last_12m_count: last_12m.count,
      first_transaction_date: invoices.minimum(:issue_date),
      last_transaction_date: invoices.maximum(:issue_date),
      payment_terms_days: @customer.payment_terms_days || @tenant.default_payment_terms_days
    }
  end

  # 支払い履歴を集計する（直近12ヶ月・月次）
  #
  # @return [Array<Hash>]
  def gather_payment_history
    invoices = @customer.documents.active
                        .where(document_type: "invoice")
                        .where("issue_date >= ?", 12.months.ago)

    (0..11).map do |i|
      month_start = (Date.current - i.months).beginning_of_month
      month_end = month_start.end_of_month
      month_invoices = invoices.where(issue_date: month_start..month_end)

      paid_count = month_invoices.where(payment_status: "paid").count
      total_count = month_invoices.count
      overdue = month_invoices.where(payment_status: %w[overdue bad_debt])

      {
        month: month_start.strftime("%Y-%m"),
        invoiced: month_invoices.sum(:total_amount),
        paid: month_invoices.sum(:paid_amount),
        count: total_count,
        on_time_rate: total_count > 0 ? (paid_count.to_f / total_count * 100).round(1) : nil,
        overdue_amount: overdue.sum(:remaining_amount)
      }
    end.reverse
  end

  # 与信スコアのトレンドを取得する
  #
  # @return [Array<Hash>]
  def credit_score_trend
    @customer.credit_score_histories
             .order(calculated_at: :desc)
             .limit(6)
             .map do |h|
      {
        date: h.calculated_at.strftime("%Y-%m-%d"),
        score: h.score
      }
    end.reverse
  end

  # Claude AIで分析コメントを生成する
  #
  # @param stats [Hash]
  # @param payment_history [Array<Hash>]
  # @return [Hash]
  def generate_ai_analysis(stats, payment_history)
    return fallback_analysis(stats) unless ai_available?

    prompt = build_prompt(stats, payment_history)
    response = call_claude_api(prompt)
    return fallback_analysis(stats) if response.blank?

    parse_analysis(response, stats)
  rescue StandardError => e
    Rails.logger.warn("AI analysis generation failed: #{e.message}")
    fallback_analysis(stats)
  end

  # AIプロンプトを構築する
  #
  # @param stats [Hash]
  # @param payment_history [Array<Hash>]
  # @return [String]
  def build_prompt(stats, payment_history)
    history_text = payment_history.map do |h|
      "#{h[:month]}: 請求¥#{format_number(h[:invoiced])} / 入金¥#{format_number(h[:paid])} / 遅延額¥#{format_number(h[:overdue_amount])}"
    end.join("\n")

    <<~PROMPT
      あなたは中小企業の経営コンサルタントです。以下の取引先データを分析し、経営者向けのアドバイスを日本語で生成してください。

      ## 取引先情報
      会社名: #{@customer.company_name}
      与信スコア: #{@customer.credit_score || '未算出'}/100
      取引開始: #{stats[:first_transaction_date] || '不明'}
      最終取引: #{stats[:last_transaction_date] || '不明'}

      ## 取引統計
      累計請求額: ¥#{format_number(stats[:total_invoiced])}
      累計入金額: ¥#{format_number(stats[:total_paid])}
      未回収残高: ¥#{format_number(stats[:total_outstanding])}
      請求件数: #{stats[:invoice_count]}件
      遅延件数: #{stats[:overdue_count]}件（遅延率#{stats[:overdue_rate]}%）
      平均支払日数: #{stats[:avg_payment_days]}日（サイト#{stats[:payment_terms_days]}日）
      直近6ヶ月請求額: ¥#{format_number(stats[:last_6m_invoiced])}（#{stats[:last_6m_count]}件）

      ## 月次支払い履歴（直近12ヶ月）
      #{history_text}

      ## 出力形式
      以下のJSON形式で回答してください:
      ```json
      {
        "risk_assessment": "low|medium|high|critical",
        "summary": "取引先の総合評価（100-200文字）",
        "recommendations": [
          "具体的なアクション推奨1",
          "具体的なアクション推奨2",
          "具体的なアクション推奨3"
        ],
        "confidence": 0.8
      }
      ```

      注意:
      - risk_assessment: low(安全), medium(注意), high(警戒), critical(危険)
      - 支払い遅延の傾向、取引規模の変化、季節性を考慮
      - 推奨アクションは具体的で実行可能なものを3つ
      - confidenceはデータの充分さに基づく（0.0〜1.0）
    PROMPT
  end

  # Claude APIを呼び出す
  #
  # @param prompt [String]
  # @return [String, nil]
  def call_claude_api(prompt)
    client = Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"])
    response = client.messages.create(
      model: "claude-haiku-4-5-20251001",
      max_tokens: 800,
      temperature: 0.2,
      messages: [{ role: "user", content: prompt }]
    )

    response.content.first.text
  rescue StandardError => e
    Rails.logger.warn("Claude API error in AiCustomerAnalyzer: #{e.message}")
    nil
  end

  # AIレスポンスをパースする
  #
  # @param response_text [String]
  # @param stats [Hash]
  # @return [Hash]
  def parse_analysis(response_text, stats)
    cleaned = response_text.gsub(/```(?:json)?\s*/, "").gsub(/```/, "").strip
    json_match = cleaned.match(/\{[\s\S]*"risk_assessment"[\s\S]*\}/m)
    return fallback_analysis(stats) unless json_match

    result = JSON.parse(json_match[0])
    risk = %w[low medium high critical].include?(result["risk_assessment"]) ? result["risk_assessment"] : determine_risk(stats)

    {
      risk_assessment: risk,
      summary: result["summary"].to_s,
      recommendations: Array(result["recommendations"]).first(5).map(&:to_s),
      confidence: (result["confidence"] || 0.5).to_f.clamp(0.0, 1.0)
    }
  rescue JSON::ParserError
    fallback_analysis(stats)
  end

  # ルールベースのリスク判定（フォールバック用）
  #
  # @param stats [Hash]
  # @return [String]
  def determine_risk(stats)
    score = @customer.credit_score || 50
    return "critical" if score < 20 || stats[:overdue_rate] > 50
    return "high" if score < 40 || stats[:overdue_rate] > 30
    return "medium" if score < 60 || stats[:overdue_rate] > 15

    "low"
  end

  # フォールバック分析結果
  #
  # @param stats [Hash]
  # @return [Hash]
  def fallback_analysis(stats)
    risk = determine_risk(stats)
    recommendations = []
    recommendations << "支払い状況を定期的に確認してください" if stats[:overdue_count].to_i > 0
    recommendations << "与信限度額の見直しを検討してください" if risk == "high" || risk == "critical"
    recommendations << "取引条件の交渉を検討してください" if stats[:avg_payment_days].to_f > stats[:payment_terms_days].to_f

    {
      risk_assessment: risk,
      summary: "与信スコア#{@customer.credit_score || '未算出'}、遅延率#{stats[:overdue_rate]}%の取引先です。",
      recommendations: recommendations.presence || ["現時点で特別な対応は不要です"],
      confidence: 0.3
    }
  end

  # フォールバック結果（全体エラー時）
  #
  # @return [Hash]
  def fallback_result
    {
      customer_id: @customer.uuid,
      company_name: @customer.company_name,
      statistics: {},
      payment_history: [],
      credit_score: @customer.credit_score,
      credit_score_trend: [],
      risk_assessment: "medium",
      summary: "分析データの取得に失敗しました。",
      recommendations: ["再度お試しください"],
      confidence: 0.0
    }
  end

  # 数値をカンマ区切りでフォーマットする
  #
  # @param number [Integer, nil]
  # @return [String]
  def format_number(number)
    number.to_i.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
  end

  # Claude APIが利用可能かチェックする
  #
  # @return [Boolean]
  def ai_available?
    ENV["ANTHROPIC_API_KEY"].present?
  end
end
