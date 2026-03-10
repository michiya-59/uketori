# frozen_string_literal: true

require "anthropic"

# AI銀行明細マッチングサービス
#
# 厳密なマッチングで銀行明細と請求書を自動消込する。
#
# 原則:
#   1. 金額一致は必須条件（金額不一致は候補にしない）
#   2. 金額一致だけでは自動マッチしない（名前一致も必要）
#   3. 名前が判定できない場合はAIに判断させる
#   4. AIでも確信がなければ「未マッチ」にする（誤マッチより未マッチが安全）
#
# @example
#   results = AiBankMatcher.call(tenant, batch_id, user: current_user)
class AiBankMatcher
  AUTO_MATCH_THRESHOLD = 0.90
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
    # @return [Hash, nil]
    def suggest(tenant, statement)
      new(tenant, nil, user: nil).suggest_for(statement)
    end
  end

  def initialize(tenant, batch_id, user:)
    @tenant = tenant
    @batch_id = batch_id
    @user = user
  end

  # バッチマッチングを実行する
  #
  # @return [Hash]
  def match!
    statements = @tenant.bank_statements.unmatched
    statements = statements.where(import_batch_id: @batch_id) if @batch_id.present?

    unpaid_invoices = load_unpaid_invoices
    results = { auto_matched: 0, needs_review: 0, unmatched: 0, auto_matched_details: [] }

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
        auto_match!(stmt, document, confidence, reason)
        results[:auto_matched] += 1
        results[:auto_matched_details] << {
          payer_name: stmt.payer_name.presence || stmt.description,
          amount: stmt.amount,
          transaction_date: stmt.transaction_date,
          document_number: document.document_number,
          customer_name: document.customer&.company_name,
          confidence: confidence
        }
        unpaid_invoices.reject! { |inv| inv.id == document.id }
      elsif confidence >= REVIEW_THRESHOLD
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
  # @return [Hash, nil]
  def find_best_match(stmt, invoices)
    # Step1: 金額で絞り込み（残額 or 総額と完全一致 ±1円のみ）
    amount_candidates = invoices.select do |inv|
      remaining = inv.remaining_amount || 0
      total = inv.total_amount || 0
      (stmt.amount - remaining).abs <= 1 || (stmt.amount - total).abs <= 1
    end

    return nil if amount_candidates.empty?

    # Step1.5: 日付で絞り込み（振込日が請求書の発行日より前のものを除外）
    amount_candidates = amount_candidates.select do |inv|
      inv.issue_date.nil? || stmt.transaction_date.nil? || stmt.transaction_date >= inv.issue_date
    end

    return nil if amount_candidates.empty?

    # Step2: ルールベースの名前マッチング
    payer = stmt.payer_name.presence || stmt.description.presence || ""
    scored = amount_candidates.map do |inv|
      name_score = calculate_name_score(payer, inv)
      { document: inv, name_score: name_score }
    end

    best_rule = scored.max_by { |c| c[:name_score] }

    # 名前が高確度で一致 → ルールベースで確定
    if best_rule[:name_score] >= 0.7
      confidence = amount_candidates.length == 1 ? 0.98 : 0.95
      return {
        document: best_rule[:document],
        confidence: confidence,
        reason: "金額一致・振込名一致"
      }
    end

    # 金額一致候補が1件＋名前がまあまあ一致
    if amount_candidates.length == 1 && best_rule[:name_score] >= 0.3
      return {
        document: best_rule[:document],
        confidence: 0.85,
        reason: "金額一致・振込名類似・候補唯一"
      }
    end

    # Step3: AI判定（名前がルールベースで判定できない場合）
    if ai_available?
      ai_result = ai_judge_match(stmt, payer, amount_candidates)
      return ai_result if ai_result
    end

    # AIが使えない or AIでも判定不能な場合
    # 金額一致候補が1件だけ → レビュー推奨として返す
    if amount_candidates.length == 1
      return {
        document: amount_candidates.first,
        confidence: 0.60,
        reason: "金額一致のみ（名前未確認）・要レビュー"
      }
    end

    nil
  end

  # ルールベースの名前スコア（0.0〜1.0）
  #
  # @param payer [String] 銀行振込名
  # @param invoice [Document]
  # @return [Float]
  def calculate_name_score(payer, invoice)
    return 0.0 if payer.blank?

    customer_name = invoice.customer&.company_name || ""
    customer_kana = invoice.customer&.company_name_kana || ""

    payer_variants = name_variants(payer)
    customer_variants = name_variants(customer_name) + name_variants(customer_kana)
    customer_variants.reject!(&:blank?)
    customer_variants.uniq!

    return 0.0 if customer_variants.empty?

    best = 0.0

    payer_variants.each do |pv|
      next if pv.blank? || pv.length < 2

      customer_variants.each do |cv|
        next if cv.blank? || cv.length < 2

        if pv == cv
          best = [best, 1.0].max
          next
        end

        shorter, longer = [pv, cv].sort_by(&:length)
        if shorter.length >= 3 && longer.include?(shorter)
          best = [best, 0.8].max
          next
        end

        sim = string_similarity(pv, cv)
        best = [best, sim].max if sim > 0.6
      end
    end

    best
  end

  # 名前のバリエーションを生成する
  #
  # @param name [String]
  # @return [Array<String>]
  def name_variants(name)
    return [] if name.blank?

    variants = []
    base = name.to_s.gsub(/[\s　]+/, "").strip
    variants << base

    # 会社法人略称を削除（銀行の半角カタカナ略称: カ）ド）ユ）ゴ））
    no_prefix = base
                .gsub(/\A[カドユゴ][）\)]\s*/, "")
                .gsub(/\A[（(]?株[）)]?\s*/, "")
                .gsub(/\A[（(]?有[）)]?\s*/, "")
                .gsub(/\A[（(]?合[）)]?\s*/, "")
    variants << no_prefix

    # 法人格を削除（漢字＋カタカナ両方対応）
    no_corp = base
              .gsub(/株式会社|有限会社|合同会社|合資会社|一般社団法人|一般財団法人/, "")
              .gsub(/カブシキガイシャ|カブシキカイシャ|ユウゲンガイシャ|ユウゲンカイシャ|ゴウドウガイシャ|ゴウドウカイシャ|ゴウシガイシャ|ゴウシカイシャ/, "")
              .gsub(/[（）\(\)]/, "")
              .gsub(/[\s　]+/, "")
    variants << no_corp

    # 半角カタカナ→全角カタカナ
    variants << to_zenkaku(base)
    variants << to_zenkaku(no_prefix)

    # 長音符の正規化（－＝全角ハイフンU+FF0D, −＝マイナスU+2212, -＝ASCIIハイフン）
    normalized = base.tr("－−\-", "ーーー")
    variants << normalized
    variants << to_zenkaku(normalized)
    variants << to_zenkaku(normalized.gsub(/\A[カドユゴ][）\)]\s*/, ""))

    # 正規化済み文字列から法人格略称も削除
    no_prefix_normalized = normalized.gsub(/\A[カドユゴ][）\)]\s*/, "")
    variants << no_prefix_normalized

    variants.map { |v| v.gsub(/[\s　]+/, "").strip.downcase }.reject(&:blank?).uniq
  end

  # 半角カタカナを全角カタカナに変換する
  #
  # @param str [String]
  # @return [String]
  def to_zenkaku(str)
    hankaku_dakuten = {
      "ｶﾞ" => "ガ", "ｷﾞ" => "ギ", "ｸﾞ" => "グ", "ｹﾞ" => "ゲ", "ｺﾞ" => "ゴ",
      "ｻﾞ" => "ザ", "ｼﾞ" => "ジ", "ｽﾞ" => "ズ", "ｾﾞ" => "ゼ", "ｿﾞ" => "ゾ",
      "ﾀﾞ" => "ダ", "ﾁﾞ" => "ヂ", "ﾂﾞ" => "ヅ", "ﾃﾞ" => "デ", "ﾄﾞ" => "ド",
      "ﾊﾞ" => "バ", "ﾋﾞ" => "ビ", "ﾌﾞ" => "ブ", "ﾍﾞ" => "ベ", "ﾎﾞ" => "ボ",
      "ﾊﾟ" => "パ", "ﾋﾟ" => "ピ", "ﾌﾟ" => "プ", "ﾍﾟ" => "ペ", "ﾎﾟ" => "ポ"
    }
    hankaku = {
      "ｱ" => "ア", "ｲ" => "イ", "ｳ" => "ウ", "ｴ" => "エ", "ｵ" => "オ",
      "ｶ" => "カ", "ｷ" => "キ", "ｸ" => "ク", "ｹ" => "ケ", "ｺ" => "コ",
      "ｻ" => "サ", "ｼ" => "シ", "ｽ" => "ス", "ｾ" => "セ", "ｿ" => "ソ",
      "ﾀ" => "タ", "ﾁ" => "チ", "ﾂ" => "ツ", "ﾃ" => "テ", "ﾄ" => "ト",
      "ﾅ" => "ナ", "ﾆ" => "ニ", "ﾇ" => "ヌ", "ﾈ" => "ネ", "ﾉ" => "ノ",
      "ﾊ" => "ハ", "ﾋ" => "ヒ", "ﾌ" => "フ", "ﾍ" => "ヘ", "ﾎ" => "ホ",
      "ﾏ" => "マ", "ﾐ" => "ミ", "ﾑ" => "ム", "ﾒ" => "メ", "ﾓ" => "モ",
      "ﾔ" => "ヤ", "ﾕ" => "ユ", "ﾖ" => "ヨ",
      "ﾗ" => "ラ", "ﾘ" => "リ", "ﾙ" => "ル", "ﾚ" => "レ", "ﾛ" => "ロ",
      "ﾜ" => "ワ", "ｦ" => "ヲ", "ﾝ" => "ン",
      "ｧ" => "ァ", "ｨ" => "ィ", "ｩ" => "ゥ", "ｪ" => "ェ", "ｫ" => "ォ",
      "ｯ" => "ッ", "ｬ" => "ャ", "ｭ" => "ュ", "ｮ" => "ョ",
      "ｰ" => "ー", "ﾞ" => "゛", "ﾟ" => "゜"
    }
    result = str.dup
    hankaku_dakuten.each { |from, to| result.gsub!(from, to) }
    hankaku.each { |from, to| result.gsub!(from, to) }
    result
  end

  # 文字列類似度（レーベンシュタイン距離ベース）
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

  # レーベンシュタイン距離
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

  # AIで名前の一致を判定する
  #
  # ルールベースで判定できない場合にClaude APIを使って判定する。
  # 銀行の半角カタカナ略称 ↔ 顧客の正式名（英語含む）の対応を判定。
  #
  # @param stmt [BankStatement]
  # @param payer [String]
  # @param candidates [Array<Document>]
  # @return [Hash, nil]
  def ai_judge_match(stmt, payer, candidates)
    invoice_list = candidates.map.with_index do |inv, i|
      customer = inv.customer
      "#{i + 1}. 請求書番号: #{inv.document_number}\n   顧客名: #{customer&.company_name}\n   顧客名カナ: #{customer&.company_name_kana.presence || '未登録'}\n   請求金額: #{inv.total_amount}円\n   残額: #{inv.remaining_amount}円"
    end.join("\n\n")

    prompt = <<~PROMPT
      あなたは銀行振込の消込を行う経理の専門家です。
      銀行明細の振込名と、候補の請求書の顧客名が同一の会社かどうかを厳密に判定してください。

      【重要なルール】
      - 銀行の振込名は半角カタカナの略称です
      - 会社法人格の略称: カ）=株式会社、ド）=合同会社、ユ）=有限会社、ゴ）=合資会社
      - 英語社名はカタカナで表記されます（例: Day One Partners → デイワンパートナーズ）
      - 「−」は長音「ー」と同じです
      - 名前が明らかに異なる会社の場合、絶対にマッチさせないでください
      - 確信が持てない場合は「該当なし」としてください
      - 誤マッチは重大な経理ミスになります。慎重に判定してください

      【銀行明細】
      振込名: #{payer}
      金額: #{stmt.amount}円
      取引日: #{stmt.transaction_date}

      【候補請求書（金額は一致済み）】
      #{invoice_list}

      振込名と顧客名が同一会社と判断できる候補があれば、その番号と確信度を回答してください。
      確信度は以下の基準で設定:
      - 0.95: 確実に同一会社（カタカナ↔英語の対応が明確）
      - 0.80: おそらく同一会社
      - 0.50以下: 不明・判定不能

      JSON形式で回答: {"index": 1, "confidence": 0.95, "reason": "カ）デイワンパートナーズ = 株式会社Day One Partners（カタカナ音訳一致）"}
      該当なしの場合: {"index": null, "confidence": 0.0, "reason": "振込名と一致する顧客なし"}
    PROMPT

    response = call_claude_api(prompt)
    Rails.logger.info("AI match response for '#{payer}': #{response}")
    return nil if response.blank?

    parse_ai_response(response, candidates)
  rescue StandardError => e
    Rails.logger.warn("AI matching failed for '#{payer}': #{e.class} #{e.message}")
    nil
  end

  # Claude APIが利用可能かチェックする
  #
  # @return [Boolean]
  def ai_available?
    ENV["ANTHROPIC_API_KEY"].present?
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
      max_tokens: 300,
      temperature: 0.0,
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
  # @param candidates [Array<Document>]
  # @return [Hash, nil]
  def parse_ai_response(response_text, candidates)
    # マークダウンコードブロックを除去してからJSON抽出
    cleaned = response_text.gsub(/```(?:json)?\s*/, "").gsub(/```/, "").strip
    json_match = cleaned.match(/\{.+\}/m)
    return nil unless json_match

    result = JSON.parse(json_match[0])
    index = result["index"]
    return nil if index.nil?

    candidate = candidates[index.to_i - 1]
    return nil unless candidate

    ai_confidence = result["confidence"].to_f
    return nil if ai_confidence < REVIEW_THRESHOLD

    {
      document: candidate,
      confidence: ai_confidence,
      reason: "AI判定: #{result['reason'] || '不明'}"
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

      stmt.update!(
        is_matched: true,
        matched_document_id: document.id,
        ai_match_confidence: confidence,
        ai_match_reason: reason
      )
    end
  end
end
