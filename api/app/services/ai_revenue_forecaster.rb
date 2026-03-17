# frozen_string_literal: true

require "anthropic"

# AI売上予測サービス
#
# 過去12ヶ月の売上実績・パイプライン・季節性を分析し、
# 統計的予測 + Claude AIによる自然言語コメントを生成する。
#
# @example
#   result = AiRevenueForecaster.call(tenant, months: 3)
#   result[:forecast]  # => [{ month: "2026-04", predicted: 5000000, ... }]
#   result[:commentary] # => "来月の売上は..."
class AiRevenueForecaster
  class << self
    # 売上予測を実行する
    #
    # @param tenant [Tenant] テナント
    # @param months [Integer] 予測月数（1〜6）
    # @return [Hash] { forecast: Array<Hash>, commentary: String, confidence: Float }
    def call(tenant, months: 3)
      new(tenant, months: months).forecast!
    end
  end

  # @param tenant [Tenant] テナント
  # @param months [Integer] 予測月数
  def initialize(tenant, months: 3)
    @tenant = tenant
    @months = months.clamp(1, 6)
  end

  # 予測を実行する
  #
  # @return [Hash]
  def forecast!
    historical = fetch_historical_data
    pipeline = fetch_pipeline_data
    statistical_forecast = calculate_statistical_forecast(historical)
    ai_commentary = generate_ai_commentary(historical, pipeline, statistical_forecast)

    {
      historical: historical,
      pipeline: pipeline,
      forecast: statistical_forecast,
      commentary: ai_commentary[:commentary],
      confidence: ai_commentary[:confidence]
    }
  rescue StandardError => e
    Rails.logger.warn("AiRevenueForecaster error: #{e.message}")
    {
      historical: fetch_historical_data_safe,
      pipeline: [],
      forecast: [],
      commentary: "予測データの生成に失敗しました。",
      confidence: 0.0
    }
  end

  private

  # 過去12ヶ月の月次売上実績を取得する
  #
  # @return [Array<Hash>]
  def fetch_historical_data
    invoices = @tenant.documents.active.where(document_type: "invoice")

    (1..12).map do |i|
      month_start = (Date.current - i.months).beginning_of_month
      month_end = month_start.end_of_month
      month_invoices = invoices.where(issue_date: month_start..month_end)

      {
        month: month_start.strftime("%Y-%m"),
        invoiced: month_invoices.sum(:total_amount),
        collected: month_invoices.sum(:paid_amount),
        count: month_invoices.count
      }
    end.reverse
  end

  # 安全な過去データ取得（エラー時フォールバック）
  #
  # @return [Array<Hash>]
  def fetch_historical_data_safe
    fetch_historical_data
  rescue StandardError
    []
  end

  # パイプラインデータ（商談中〜受注の案件）を取得する
  #
  # @return [Array<Hash>]
  def fetch_pipeline_data
    @tenant.projects.active
           .where(status: %w[negotiation won in_progress])
           .where.not(amount: nil)
           .order(:end_date)
           .limit(20)
           .map do |project|
      {
        name: project.name,
        amount: project.amount,
        probability: project.probability || 50,
        status: project.status,
        expected_date: project.end_date&.strftime("%Y-%m")
      }
    end
  end

  # 統計的予測（移動平均 + 季節性調整）
  #
  # @param historical [Array<Hash>]
  # @return [Array<Hash>]
  def calculate_statistical_forecast(historical)
    return [] if historical.empty?

    amounts = historical.map { |h| h[:invoiced] }

    # 直近3ヶ月の移動平均
    recent_avg = if amounts.last(3).any? { |a| a > 0 }
                   amounts.last(3).sum.to_f / 3
                 else
                   0
                 end

    # 直近6ヶ月の移動平均
    mid_avg = if amounts.last(6).any? { |a| a > 0 }
                amounts.last(6).sum.to_f / 6
              else
                0
              end

    # トレンド係数（直近3ヶ月 vs 6ヶ月平均）
    trend = mid_avg > 0 ? (recent_avg / mid_avg) : 1.0

    # 季節性指数の計算（同月の過去データがあれば適用）
    (1..@months).map do |i|
      target_month = Date.current + i.months
      month_num = target_month.month

      # 同月の過去データ
      same_month_data = historical.select { |h| Date.parse("#{h[:month]}-01").month == month_num }
      seasonality = if same_month_data.any? && mid_avg > 0
                      same_month_avg = same_month_data.map { |d| d[:invoiced] }.sum.to_f / same_month_data.size
                      (same_month_avg / mid_avg).clamp(0.5, 2.0)
                    else
                      1.0
                    end

      predicted = (recent_avg * trend * seasonality).round(0).to_i
      predicted = 0 if predicted < 0

      # パイプラインからの追加見込み
      pipeline_amount = pipeline_for_month(target_month)

      {
        month: target_month.beginning_of_month.strftime("%Y-%m"),
        predicted: predicted,
        pipeline_amount: pipeline_amount,
        trend_factor: trend.round(3),
        seasonality_factor: seasonality.round(3),
        lower_bound: (predicted * 0.8).round(0).to_i,
        upper_bound: (predicted * 1.2).round(0).to_i
      }
    end
  end

  # 指定月のパイプライン見込み額を計算する
  #
  # @param target_month [Date] 対象月
  # @return [Integer]
  def pipeline_for_month(target_month)
    month_str = target_month.beginning_of_month.strftime("%Y-%m")
    pipeline = fetch_pipeline_data

    pipeline.select { |p| p[:expected_date] == month_str }
            .sum { |p| (p[:amount] * p[:probability] / 100.0).round(0).to_i }
  end

  # Claude AIによる解説コメントを生成する
  #
  # @param historical [Array<Hash>]
  # @param pipeline [Array<Hash>]
  # @param forecast [Array<Hash>]
  # @return [Hash] { commentary: String, confidence: Float }
  def generate_ai_commentary(historical, pipeline, forecast)
    return { commentary: fallback_commentary(forecast), confidence: 0.3 } unless ai_available?

    prompt = build_prompt(historical, pipeline, forecast)
    response = call_claude_api(prompt)
    return { commentary: fallback_commentary(forecast), confidence: 0.3 } if response.blank?

    parse_commentary(response, forecast)
  rescue StandardError => e
    Rails.logger.warn("AI commentary generation failed: #{e.message}")
    { commentary: fallback_commentary(forecast), confidence: 0.3 }
  end

  # AIプロンプトを構築する
  #
  # @param historical [Array<Hash>]
  # @param pipeline [Array<Hash>]
  # @param forecast [Array<Hash>]
  # @return [String]
  def build_prompt(historical, pipeline, forecast)
    hist_text = historical.map { |h| "#{h[:month]}: 請求額¥#{h[:invoiced].to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')} (#{h[:count]}件)" }.join("\n")
    pipe_text = pipeline.map { |p| "#{p[:name]}: ¥#{p[:amount].to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')} (確度#{p[:probability]}%, #{p[:status]})" }.join("\n")
    forecast_text = forecast.map { |f| "#{f[:month]}: 予測¥#{f[:predicted].to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')}" }.join("\n")

    <<~PROMPT
      あなたは中小企業の経営アドバイザーです。以下の売上データを分析し、経営者向けの売上予測コメントを日本語で生成してください。

      ## 過去12ヶ月の売上実績
      #{hist_text.presence || "（データなし）"}

      ## 進行中のパイプライン
      #{pipe_text.presence || "（パイプラインなし）"}

      ## 統計予測
      #{forecast_text.presence || "（予測なし）"}

      ## 出力形式
      以下のJSON形式で回答してください:
      ```json
      {
        "commentary": "来月の売上予測コメント（100-200文字、トレンド・リスク・推奨アクションを含む）",
        "confidence": 0.7
      }
      ```

      注意:
      - confidenceは0.0〜1.0。データが豊富なら高く、少なければ低く設定
      - 具体的な金額を含めてください
      - 前月比・前年同月比がわかれば言及してください
      - リスク要因があれば簡潔に触れてください
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
      max_tokens: 500,
      temperature: 0.3,
      messages: [{ role: "user", content: prompt }]
    )

    response.content.first.text
  rescue StandardError => e
    Rails.logger.warn("Claude API error in AiRevenueForecaster: #{e.message}")
    nil
  end

  # AIレスポンスをパースする
  #
  # @param response_text [String]
  # @param forecast [Array<Hash>]
  # @return [Hash]
  def parse_commentary(response_text, forecast)
    cleaned = response_text.gsub(/```(?:json)?\s*/, "").gsub(/```/, "").strip
    json_match = cleaned.match(/\{[\s\S]*"commentary"[\s\S]*\}/m)
    return { commentary: fallback_commentary(forecast), confidence: 0.3 } unless json_match

    result = JSON.parse(json_match[0])
    {
      commentary: result["commentary"].to_s,
      confidence: (result["confidence"] || 0.5).to_f.clamp(0.0, 1.0)
    }
  rescue JSON::ParserError
    { commentary: fallback_commentary(forecast), confidence: 0.3 }
  end

  # フォールバックコメントを生成する
  #
  # @param forecast [Array<Hash>]
  # @return [String]
  def fallback_commentary(forecast)
    return "予測データが不足しています。" if forecast.nil? || forecast.empty?

    next_month = forecast.first
    "来月（#{next_month[:month]}）の売上予測は約¥#{next_month[:predicted].to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')}です。"
  end

  # Claude APIが利用可能かチェックする
  #
  # @return [Boolean]
  def ai_available?
    ENV["ANTHROPIC_API_KEY"].present?
  end
end
