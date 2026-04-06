# frozen_string_literal: true

require "anthropic"

# AI銀行明細マッチングサービス
#
# 厳密なマッチングで銀行明細と請求書を自動消込する。
#
# 原則:
#   1. 金額一致は必須条件（金額不一致は候補にしない）
#   2. 名前は正規化後に完全一致するものだけ候補にする
#   3. 類似・部分一致・AI推定では自動マッチさせない
#   4. 確信が持てない場合は必ず「未マッチ」にする
#
# @example
#   results = AiBankMatcher.call(tenant, batch_id, user: current_user)
class AiBankMatcher
  AUTO_MATCH_THRESHOLD = 0.90
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

    # Step2: 正規化後の完全一致だけを許可する
    payer = stmt.payer_name.presence || stmt.description.presence || ""
    scored = amount_candidates.map do |inv|
      name_score = calculate_name_score(payer, inv)
      { document: inv, name_score: name_score, recency_score: calculate_recency_score(stmt, inv) }
    end

    best_rule = scored.max_by { |c| [c[:name_score], c[:recency_score], c[:document].id] }
    return nil unless best_rule && best_rule[:name_score] == 1.0

    confidence = amount_candidates.length == 1 ? 0.98 : 0.95
    {
      document: best_rule[:document],
      confidence: confidence,
      reason: "金額一致・振込名完全一致"
    }
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

    payer_variants.each do |pv|
      next if pv.blank? || pv.length < 2

      customer_variants.each do |cv|
        next if cv.blank? || cv.length < 2

        return 1.0 if pv == cv
      end
    end

    0.0
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
    no_prefix = strip_corporate_abbreviation(base)
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
    variants << to_zenkaku(strip_corporate_abbreviation(normalized))

    # 正規化済み文字列から法人格略称も削除
    no_prefix_normalized = strip_corporate_abbreviation(normalized)
    variants << no_prefix_normalized

    variants.map { |v| v.gsub(/[\s　]+/, "").strip.downcase }.reject(&:blank?).uniq
  end

  # 銀行表記の法人格略称を前方・後方の両方から除去する
  #
  # 例:
  # - カ）テスト -> テスト
  # - ライズ（ド -> ライズ
  #
  # @param value [String]
  # @return [String]
  def strip_corporate_abbreviation(value)
    value
      .gsub(/\A[カドユゴ][）\)]\s*/, "")
      .gsub(/\A[（(]?[株有合][）)]?\s*/, "")
      .gsub(/\s*[（(][カドユゴ]\z/, "")
      .gsub(/\s*[株有合][）)]\z/, "")
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

  # 取引日に近い請求書を優先するためのスコア
  #
  # 同額・同一顧客の請求書が複数ある場合は、
  # 入金日の直前に最も近い due_date / issue_date を優先する。
  #
  # @param stmt [BankStatement]
  # @param invoice [Document]
  # @return [Float]
  def calculate_recency_score(stmt, invoice)
    return 0.0 if stmt.transaction_date.nil?

    anchor_date = invoice.due_date || invoice.issue_date
    return 0.0 if anchor_date.nil?

    diff_days = (stmt.transaction_date - anchor_date).to_i.abs
    1.0 / (diff_days + 1)
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
