# frozen_string_literal: true

# AI銀行明細マッチングサービス
#
# 5ステップのマッチングアルゴリズムで銀行明細と請求書を自動消込する。
#
# Step1: ルールベース（金額完全一致 ± 1円）
# Step2: 名前正規化（カタカナ正規化 + 部分一致）
# Step3: AI補完（Claude Haiku, confidence < 0.7）
# Step4: 結果分類（auto_matched ≥ 0.90 / needs_review 0.70-0.89 / unmatched < 0.70）
# Step5: auto_matched の入金レコード自動作成
#
# @example
#   results = AiBankMatcher.call(tenant, batch_id, user: current_user)
#   results[:auto_matched]  # => 30
#   results[:needs_review]  # => 10
#   results[:unmatched]     # => 10
class AiBankMatcher
  # 自動マッチングの信頼度閾値
  AUTO_MATCH_THRESHOLD = 0.90
  # レビュー推奨の信頼度閾値
  REVIEW_THRESHOLD = 0.70

  class << self
    # バッチ単位でマッチングを実行する
    #
    # @param tenant [Tenant] テナント
    # @param batch_id [String] インポートバッチID
    # @param user [User] 実行ユーザー
    # @return [Hash] { auto_matched: Integer, needs_review: Integer, unmatched: Integer }
    def call(tenant, batch_id, user:)
      new(tenant, batch_id, user: user).match!
    end

    # 単一明細のAI提案を取得する
    #
    # @param tenant [Tenant] テナント
    # @param statement [BankStatement] 銀行明細
    # @return [Hash] { document: Document, confidence: Float, reason: String }
    def suggest(tenant, statement)
      new(tenant, nil, user: nil).suggest_for(statement)
    end
  end

  # @param tenant [Tenant]
  # @param batch_id [String, nil]
  # @param user [User, nil]
  def initialize(tenant, batch_id, user:)
    @tenant = tenant
    @batch_id = batch_id
    @user = user
  end

  # バッチマッチングを実行する
  #
  # @return [Hash] マッチング結果サマリー
  def match!
    statements = @tenant.bank_statements.unmatched
    statements = statements.where(import_batch_id: @batch_id) if @batch_id.present?

    unpaid_invoices = load_unpaid_invoices
    results = { auto_matched: 0, needs_review: 0, unmatched: 0 }

    statements.find_each do |stmt|
      match_result = find_best_match(stmt, unpaid_invoices)

      if match_result.nil?
        results[:unmatched] += 1
        next
      end

      confidence = match_result[:confidence]
      document = match_result[:document]
      reason = match_result[:reason]

      if confidence >= AUTO_MATCH_THRESHOLD
        # 自動マッチング → 入金レコード作成
        auto_match!(stmt, document, confidence, reason)
        results[:auto_matched] += 1
        # マッチ済み請求書をリストから除外
        unpaid_invoices.reject! { |inv| inv.id == document.id }
      elsif confidence >= REVIEW_THRESHOLD
        # レビュー推奨
        stmt.update!(
          ai_suggested_document_id: document.id,
          ai_match_confidence: confidence,
          ai_match_reason: reason
        )
        results[:needs_review] += 1
      else
        results[:unmatched] += 1
      end
    end

    results
  end

  # 単一明細のAI提案を生成する
  #
  # @param statement [BankStatement]
  # @return [Hash, nil]
  def suggest_for(statement)
    invoices = load_unpaid_invoices
    find_best_match(statement, invoices)
  end

  private

  # 未払い請求書一覧を取得する
  #
  # @return [Array<Document>]
  def load_unpaid_invoices
    @tenant.documents
           .where(document_type: "invoice")
           .where(payment_status: %w[unpaid partial overdue])
           .includes(:customer)
           .to_a
  end

  # 最適なマッチング候補を見つける
  #
  # @param stmt [BankStatement]
  # @param invoices [Array<Document>]
  # @return [Hash, nil] { document: Document, confidence: Float, reason: String }
  def find_best_match(stmt, invoices)
    candidates = []

    invoices.each do |inv|
      score, reasons = calculate_match_score(stmt, inv)
      candidates << { document: inv, confidence: score, reason: reasons.join("、") } if score > 0.3
    end

    return nil if candidates.empty?

    best = candidates.max_by { |c| c[:confidence] }

    # Step3: 信頼度が低い場合、AI補完を試みる
    if best[:confidence] < REVIEW_THRESHOLD && ai_available?
      ai_result = ai_enhance_match(stmt, candidates.first(5))
      best = ai_result if ai_result && ai_result[:confidence] > best[:confidence]
    end

    best
  end

  # ルールベースのスコア計算
  #
  # @param stmt [BankStatement]
  # @param invoice [Document]
  # @return [Array(Float, Array<String>)] [スコア, 理由リスト]
  def calculate_match_score(stmt, invoice)
    score = 0.0
    reasons = []

    # Step1: 金額マッチング（±1円以内で高スコア）
    remaining = invoice.remaining_amount || 0
    amount_diff = (stmt.amount - remaining).abs

    if amount_diff <= 1
      score += 0.50
      reasons << "金額完全一致"
    elsif amount_diff <= remaining * 0.01
      score += 0.30
      reasons << "金額近似(#{amount_diff}円差)"
    elsif stmt.amount == invoice.total_amount
      score += 0.40
      reasons << "総額一致"
    end

    # Step2: 名前マッチング
    name_score = calculate_name_score(stmt, invoice)
    if name_score > 0
      score += name_score
      reasons << "振込名一致" if name_score >= 0.3
      reasons << "振込名類似" if name_score > 0 && name_score < 0.3
    end

    # 日付近接ボーナス（支払期日付近の入金）
    if invoice.due_date.present? && stmt.transaction_date.present?
      days_diff = (stmt.transaction_date - invoice.due_date).abs
      if days_diff <= 7
        score += 0.10
        reasons << "期日付近"
      end
    end

    [score.clamp(0.0, 1.0), reasons]
  end

  # 名前スコアを計算する
  #
  # @param stmt [BankStatement]
  # @param invoice [Document]
  # @return [Float]
  def calculate_name_score(stmt, invoice)
    payer = normalize_name(stmt.payer_name || stmt.description)
    customer = normalize_name(invoice.customer&.company_name || "")
    customer_kana = normalize_name(invoice.customer&.company_name_kana || "")

    return 0.0 if payer.blank?

    # 完全一致
    return 0.40 if payer == customer || payer == customer_kana

    # 部分一致
    return 0.30 if payer.include?(customer) || customer.include?(payer)
    return 0.30 if customer_kana.present? && (payer.include?(customer_kana) || customer_kana.include?(payer))

    # レーベンシュタイン距離による類似度
    similarity = string_similarity(payer, customer)
    kana_similarity = customer_kana.present? ? string_similarity(payer, customer_kana) : 0
    best_similarity = [similarity, kana_similarity].max

    return 0.20 if best_similarity > 0.7
    return 0.10 if best_similarity > 0.5

    0.0
  end

  # 名前を正規化する
  #
  # @param name [String]
  # @return [String]
  def normalize_name(name)
    return "" if name.blank?

    name.to_s
        .gsub(/カ[）\)]|ユ[）\)]|ド[）\)]|ゴ[）\)]/, "")
        .gsub(/株式会社|有限会社|合同会社|合資会社/, "")
        .gsub(/[（）\(\)「」『』【】]/, "")
        .gsub(/\s+/, "")
        .strip
  end

  # 文字列の類似度を計算する（簡易レーベンシュタイン距離ベース）
  #
  # @param s1 [String]
  # @param s2 [String]
  # @return [Float] 0.0〜1.0
  def string_similarity(s1, s2)
    return 1.0 if s1 == s2
    return 0.0 if s1.blank? || s2.blank?

    max_len = [s1.length, s2.length].max
    distance = levenshtein_distance(s1, s2)
    1.0 - (distance.to_f / max_len)
  end

  # レーベンシュタイン距離を計算する
  #
  # @param s1 [String]
  # @param s2 [String]
  # @return [Integer]
  def levenshtein_distance(s1, s2)
    m = s1.length
    n = s2.length
    d = Array.new(m + 1) { Array.new(n + 1, 0) }

    (0..m).each { |i| d[i][0] = i }
    (0..n).each { |j| d[0][j] = j }

    (1..m).each do |i|
      (1..n).each do |j|
        cost = s1[i - 1] == s2[j - 1] ? 0 : 1
        d[i][j] = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost].min
      end
    end

    d[m][n]
  end

  # Claude APIが利用可能かチェックする
  #
  # @return [Boolean]
  def ai_available?
    ENV["ANTHROPIC_API_KEY"].present?
  end

  # AIでマッチング精度を補完する
  #
  # @param stmt [BankStatement]
  # @param candidates [Array<Hash>]
  # @return [Hash, nil]
  def ai_enhance_match(stmt, candidates)
    return nil if candidates.empty?

    prompt = build_ai_prompt(stmt, candidates)
    response = call_claude_api(prompt)
    return nil if response.blank?

    parse_ai_response(response, candidates)
  rescue StandardError => e
    Rails.logger.warn("AI matching failed: #{e.message}")
    nil
  end

  # AI用プロンプトを構築する
  #
  # @param stmt [BankStatement]
  # @param candidates [Array<Hash>]
  # @return [String]
  def build_ai_prompt(stmt, candidates)
    invoice_list = candidates.map.with_index do |c, i|
      inv = c[:document]
      "#{i + 1}. #{inv.document_number} - #{inv.customer&.company_name} - 残額¥#{inv.remaining_amount} - 期日#{inv.due_date}"
    end.join("\n")

    <<~PROMPT
      銀行明細と請求書のマッチングを行ってください。

      【銀行明細】
      - 取引日: #{stmt.transaction_date}
      - 振込名: #{stmt.payer_name || stmt.description}
      - 金額: ¥#{stmt.amount}

      【候補請求書】
      #{invoice_list}

      最も一致する可能性が高い候補番号と信頼度(0.0-1.0)、理由を以下のJSON形式で回答してください:
      {"index": 1, "confidence": 0.85, "reason": "金額一致、社名類似"}

      該当なしの場合: {"index": null, "confidence": 0.0, "reason": "該当なし"}
    PROMPT
  end

  # Claude APIを呼び出す
  #
  # @param prompt [String]
  # @return [String, nil]
  def call_claude_api(prompt)
    return nil unless ai_available?

    client = Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"])
    response = client.messages.create(
      model: "claude-haiku-4-5-20251001",
      max_tokens: 200,
      messages: [{ role: "user", content: prompt }]
    )

    response.content.first.text
  rescue StandardError => e
    Rails.logger.warn("Claude API error: #{e.message}")
    nil
  end

  # AIレスポンスをパースする
  #
  # @param response_text [String]
  # @param candidates [Array<Hash>]
  # @return [Hash, nil]
  def parse_ai_response(response_text, candidates)
    json_match = response_text.match(/\{[^}]+\}/)
    return nil unless json_match

    result = JSON.parse(json_match[0])
    index = result["index"]
    return nil if index.nil?

    candidate = candidates[index.to_i - 1]
    return nil unless candidate

    {
      document: candidate[:document],
      confidence: result["confidence"].to_f,
      reason: result["reason"] || "AI判定"
    }
  rescue JSON::ParserError
    nil
  end

  # 自動マッチングを実行して入金レコードを作成する
  #
  # @param stmt [BankStatement]
  # @param document [Document]
  # @param confidence [Float]
  # @param reason [String]
  # @return [void]
  def auto_match!(stmt, document, confidence, reason)
    ActiveRecord::Base.transaction do
      # 入金レコード作成
      PaymentRecord.create!(
        tenant: @tenant,
        document: document,
        bank_statement: stmt,
        recorded_by_user: @user,
        uuid: SecureRandom.uuid,
        amount: stmt.amount,
        payment_date: stmt.transaction_date,
        payment_method: "bank_transfer",
        matched_by: "ai_auto",
        match_confidence: confidence,
        memo: "AI自動消込: #{reason}"
      )

      # 銀行明細をマッチ済みに更新
      stmt.update!(
        is_matched: true,
        matched_document_id: document.id,
        ai_match_confidence: confidence,
        ai_match_reason: reason
      )
    end
  end
end
