# frozen_string_literal: true

module Api
  module V1
    # AI機能を統合的に提供するコントローラー
    #
    # AI見積提案・AI売上予測・AI取引先分析のエンドポイントを提供する。
    # AI入金消込は既存のBankStatementsControllerで提供。
    class AiController < BaseController
      # AI見積提案
      #
      # 顧客の過去取引・品目マスタを参照し、明細行を自動提案する。
      #
      # @return [void]
      def estimate_suggestion
        PlanLimitChecker.new(current_tenant).check!(:ai_matching)

        customer = policy_scope(Customer).find_by_uuid!(params[:customer_id])
        project_description = params[:project_description].to_s
        hints = Array(params[:hints])

        result = generate_estimate_suggestion(customer, project_description, hints)

        render json: {
          suggestions: result[:items],
          confidence: result[:confidence]
        }
      end

      # AI売上予測
      #
      # 過去の売上実績・パイプラインデータを分析し、将来の売上を予測する。
      #
      # @return [void]
      def revenue_forecast
        PlanLimitChecker.new(current_tenant).check!(:ai_matching)

        months = (params[:months] || 3).to_i
        result = AiRevenueForecaster.call(current_tenant, months: months)

        render json: result
      end

      # AI取引先分析
      #
      # 顧客の取引データ・支払い傾向を総合分析する。
      #
      # @return [void]
      def customer_analysis
        PlanLimitChecker.new(current_tenant).check!(:ai_matching)

        customer = policy_scope(Customer).find_by_uuid!(params[:id])
        result = AiCustomerAnalyzer.call(customer)

        render json: result
      end

      private

      # AI見積提案を生成する（拡張版）
      #
      # AiDocumentSuggesterを拡張し、project_descriptionとhintsを考慮する。
      #
      # @param customer [Customer] 顧客
      # @param project_description [String] 案件説明
      # @param hints [Array<String>] ヒント情報
      # @return [Hash]
      def generate_estimate_suggestion(customer, project_description, hints)
        # 同一顧客の過去見積書を最大10件取得
        past_estimates = current_tenant.documents.active
                                       .where(customer: customer)
                                       .where(document_type: %w[estimate invoice])
                                       .includes(:document_items)
                                       .order(created_at: :desc)
                                       .limit(10)

        # 類似案件の見積書を最大10件取得
        similar_docs = if project_description.present?
                         current_tenant.documents.active
                                       .where(document_type: %w[estimate invoice])
                                       .where("title ILIKE ?", "%#{sanitize_like(project_description.split(/\s+/).first(3).join('%'))}%")
                                       .where.not(customer: customer)
                                       .includes(:document_items)
                                       .order(created_at: :desc)
                                       .limit(10)
                       else
                         Document.none
                       end

        # 品目マスタ
        products = current_tenant.products.where(is_active: true).order(:name).limit(50)

        prompt = build_estimate_prompt(customer, project_description, hints, past_estimates, similar_docs, products)
        response = call_claude_api(prompt)

        return { items: [], confidence: 0.0 } if response.blank?

        parse_suggestion_response(response)
      rescue StandardError => e
        Rails.logger.warn("AI estimate suggestion error: #{e.message}")
        { items: [], confidence: 0.0 }
      end

      # LIKE演算のワイルドカードをエスケープする
      #
      # @param value [String]
      # @return [String]
      def sanitize_like(value)
        value.gsub("%", "\\%").gsub("_", "\\_")
      end

      # AI見積提案用プロンプトを構築する
      #
      # @param customer [Customer]
      # @param description [String]
      # @param hints [Array<String>]
      # @param past_estimates [ActiveRecord::Relation]
      # @param similar_docs [ActiveRecord::Relation]
      # @param products [ActiveRecord::Relation]
      # @return [String]
      def build_estimate_prompt(customer, description, hints, past_estimates, similar_docs, products)
        past_text = past_estimates.flat_map do |doc|
          doc.document_items.map do |item|
            "- #{item.name}: 数量#{item.quantity} #{item.unit}, 単価¥#{item.unit_price}"
          end
        end.join("\n")

        similar_text = similar_docs.flat_map do |doc|
          ["[#{doc.title}] #{doc.customer&.company_name}:"] +
            doc.document_items.map { |item| "  - #{item.name}: 数量#{item.quantity} #{item.unit}, 単価¥#{item.unit_price}" }
        end.join("\n")

        products_text = products.map { |p| "- #{p.name}: 単価¥#{p.unit_price} (#{p.unit})" }.join("\n")

        <<~PROMPT
          あなたは日本の中小企業向け見積システムのAIアシスタントです。
          以下の情報を参考に、最適な見積明細を提案してください。

          ## 顧客情報
          顧客名: #{customer.company_name}

          ## 案件内容
          #{description.presence || "（未記入）"}

          ## ヒント・要望
          #{hints.presence ? hints.join(", ") : "（なし）"}

          ## 同一顧客の過去見積（最大10件）
          #{past_text.presence || "（過去の取引なし）"}

          ## 類似案件の見積
          #{similar_text.presence || "（類似案件なし）"}

          ## 利用可能な品目マスタ
          #{products_text.presence || "（品目未登録）"}

          ## 出力形式
          以下のJSON形式で3〜8件の明細を提案してください:
          ```json
          {
            "items": [
              {
                "name": "品名",
                "quantity": 1,
                "unit": "式",
                "unit_price": 100000,
                "tax_rate_type": "standard",
                "reason": "提案理由"
              }
            ],
            "confidence": 0.85
          }
          ```

          重要:
          - 過去データがある場合はそれを参考に
          - 品目マスタにあるものは名称・単価を流用
          - 案件内容とヒントに沿った提案を
          - confidenceは過去データの充実度に応じて0.0〜1.0
        PROMPT
      end

      # Claude APIを呼び出す
      #
      # @param prompt [String]
      # @return [String, nil]
      def call_claude_api(prompt)
        api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)
        return nil if api_key.blank?

        client = Anthropic::Client.new(api_key: api_key)
        response = client.messages.create(
          model: "claude-sonnet-4-20250514",
          max_tokens: 2000,
          temperature: 0.3,
          messages: [{ role: "user", content: prompt }]
        )

        response.content.first.text
      rescue StandardError => e
        Rails.logger.warn("Claude API error in AiController: #{e.message}")
        nil
      end

      # AI見積提案レスポンスをパースする
      #
      # @param response_text [String]
      # @return [Hash]
      def parse_suggestion_response(response_text)
        cleaned = response_text.gsub(/```(?:json)?\s*/, "").gsub(/```/, "").strip
        json_match = cleaned.match(/\{[\s\S]*"items"[\s\S]*\}/m)
        return { items: [], confidence: 0.0 } unless json_match

        result = JSON.parse(json_match[0])
        items = (result["items"] || []).map do |item|
          {
            name: item["name"].to_s,
            quantity: item["quantity"].to_f,
            unit: item["unit"].to_s,
            unit_price: item["unit_price"].to_i,
            tax_rate_type: item["tax_rate_type"] || "standard",
            reason: item["reason"].to_s
          }
        end

        {
          items: items,
          confidence: (result["confidence"] || 0.5).to_f.clamp(0.0, 1.0)
        }
      rescue JSON::ParserError
        { items: [], confidence: 0.0 }
      end
    end
  end
end
