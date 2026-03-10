# frozen_string_literal: true

module Api
  module V1
    # 銀行明細コントローラー
    #
    # 銀行明細のCSVインポート、一覧取得、AIマッチング、
    # 手動マッチングの機能を提供する。
    class BankStatementsController < BaseController
      before_action :set_statement, only: %i[match ai_suggest]

      # 銀行明細一覧を返す
      #
      # @return [void]
      def index
        statements = policy_scope(BankStatement)
                     .order(transaction_date: :desc, created_at: :desc)
                     .page(page_param).per(per_page_param)

        render json: {
          bank_statements: statements.map { |s| serialize_statement(s) },
          meta: pagination_meta(statements)
        }
      end

      # 画像/PDFからOCRプレビューを取得する
      #
      # ダブルパス検証で抽出し、信頼度付きの行データを返す。
      # ユーザーが確認・修正した後、import_confirmedで確定する。
      #
      # @return [void]
      def ocr_preview
        authorize BankStatement, :import?

        file = params[:file]
        unless file.present?
          return render json: { error: { code: "validation_error", message: "ファイルが指定されていません" } },
                        status: :unprocessable_entity
        end

        file_data = file.read
        content_type = file.content_type
        filename = file.original_filename || ""

        # 拡張子からcontent_typeを補完
        if content_type.blank? || content_type == "application/octet-stream"
          content_type = mime_from_extension(filename)
        end

        extraction = BankStatementOcrExtractor.call(
          file_data,
          content_type: content_type,
          filename: filename
        )

        render json: {
          rows: extraction[:rows],
          warnings_count: extraction[:warnings_count]
        }
      rescue BankStatementOcrExtractor::ExtractionError => e
        render json: { error: { code: "ocr_error", message: e.message } },
               status: :unprocessable_entity
      end

      # 確認済みOCRデータまたはCSVをインポートする
      #
      # CSV: params[:file] でアップロード
      # OCR確認済み: params[:confirmed_rows] でJSON送信
      #
      # @return [void]
      def import
        authorize BankStatement, :import?

        bank_format = params[:bank_format]

        if params[:confirmed_rows].present?
          # OCR確認済みデータのインポート
          result = import_confirmed_rows(params[:confirmed_rows], bank_format: bank_format)
        elsif params[:file].present?
          file = params[:file]
          content_type = file.content_type
          filename = file.original_filename || ""

          if ocr_file?(content_type, filename)
            return render json: { error: { code: "validation_error",
                                           message: "画像/PDFはまずocr_previewで確認してください" } },
                          status: :unprocessable_entity
          end

          result = import_csv(file, filename: filename, bank_format: bank_format)
        else
          return render json: { error: { code: "validation_error", message: "ファイルまたは確認済みデータが必要です" } },
                        status: :unprocessable_entity
        end

        AuditLogger.log(
          user: current_user,
          action: "import",
          resource: current_tenant,
          changes: { imported: result[:imported], skipped: result[:skipped], batch_id: result[:batch_id] }
        )

        render json: {
          imported: result[:imported],
          skipped: result[:skipped],
          batch_id: result[:batch_id]
        }, status: :created
      rescue BankStatementImporter::ImportError => e
        render json: { error: { code: "import_error", message: e.message } },
               status: :unprocessable_entity
      end

      # 未消込の明細一覧を返す
      #
      # @return [void]
      def unmatched
        authorize BankStatement, :unmatched?

        statements = policy_scope(BankStatement).unmatched
                     .includes(ai_suggested_document: :customer)
                     .order(transaction_date: :desc)
        statements = statements.where(import_batch_id: params[:batch_id]) if params[:batch_id].present?
        statements = statements.page(page_param).per(per_page_param)

        render json: {
          bank_statements: statements.map { |s| serialize_statement_with_suggestion(s) },
          meta: pagination_meta(statements)
        }
      end

      # 手動マッチングを行う
      #
      # @return [void]
      def match
        authorize @statement, :match?

        document = policy_scope(Document).find_by_uuid!(params[:document_uuid])

        ActiveRecord::Base.transaction do
          PaymentRecord.create!(
            tenant: current_tenant,
            document: document,
            bank_statement: @statement,
            recorded_by_user: current_user,
            uuid: SecureRandom.uuid,
            amount: @statement.amount,
            payment_date: @statement.transaction_date,
            payment_method: "bank_transfer",
            matched_by: "manual"
          )

          @statement.update!(
            is_matched: true,
            matched_document_id: document.id
          )

          # 顧客の未回収残高を更新
          update_customer_outstanding!(document.customer)
        end

        render json: { bank_statement: serialize_statement(@statement.reload) }
      end

      # バッチAIマッチングを実行する
      #
      # @return [void]
      def ai_match
        authorize BankStatement, :ai_match?
        PlanLimitChecker.new(current_tenant).check!(:ai_matching)

        batch_id = params[:batch_id]
        results = AiBankMatcher.call(current_tenant, batch_id, user: current_user)

        render json: results
      end

      # 単一明細のAI提案を取得する
      #
      # @return [void]
      def ai_suggest
        authorize @statement, :ai_suggest?
        PlanLimitChecker.new(current_tenant).check!(:ai_matching)

        result = AiBankMatcher.suggest(current_tenant, @statement)

        if result
          @statement.update!(
            ai_suggested_document_id: result[:document].id,
            ai_match_confidence: result[:confidence],
            ai_match_reason: result[:reason]
          )
          render json: {
            suggestion: {
              document_uuid: result[:document].uuid,
              document_number: result[:document].document_number,
              customer_name: result[:document].customer&.company_name,
              confidence: result[:confidence],
              reason: result[:reason]
            }
          }
        else
          render json: { suggestion: nil }
        end
      end

      private

      # @return [void]
      def set_statement
        @statement = policy_scope(BankStatement).find(params[:id])
      end

      # OCR対象ファイルかどうかを判定する
      #
      # @param content_type [String]
      # @param filename [String]
      # @return [Boolean]
      def ocr_file?(content_type, filename)
        return true if BankStatementOcrExtractor.supported?(content_type)

        ext = File.extname(filename).downcase
        %w[.jpg .jpeg .png .gif .webp .pdf].include?(ext)
      end

      # ユーザーが確認・修正済みのOCRデータをインポートする
      #
      # @param rows_params [Array<Hash>] [{ date:, description:, amount: }, ...]
      # @param bank_format [String, nil]
      # @return [Hash] { imported: Integer, skipped: Integer, batch_id: String }
      def import_confirmed_rows(rows_params, bank_format: nil)
        rows = rows_params.map { |r| r.is_a?(ActionController::Parameters) ? r.permit(:date, :description, :amount).to_h : r }

        csv_lines = ["取引日,摘要,金額"]
        rows.each { |row| csv_lines << "#{row['date'] || row[:date]},#{row['description'] || row[:description]},#{row['amount'] || row[:amount]}" }
        csv_data = csv_lines.join("\n")

        # OCR確認済みデータは常に「取引日,摘要,金額」の3列固定フォーマット
        # ユーザー選択の銀行フォーマットは無関係なので常にgenericで処理する
        BankStatementImporter.call(
          current_tenant, csv_data,
          filename: "ocr_confirmed.csv", bank_format: "generic"
        )
      end

      # CSVファイルをインポートする
      #
      # @param file [ActionDispatch::Http::UploadedFile]
      # @param filename [String]
      # @param bank_format [String, nil]
      # @return [Hash]
      def import_csv(file, filename:, bank_format:)
        csv_data = file.read
        BankStatementImporter.call(
          current_tenant, csv_data,
          filename: filename, bank_format: bank_format
        )
      end

      # ファイル拡張子からMIMEタイプを推定する
      #
      # @param filename [String, nil]
      # @return [String]
      def mime_from_extension(filename)
        ext = File.extname(filename.to_s).downcase
        case ext
        when ".jpg", ".jpeg" then "image/jpeg"
        when ".png" then "image/png"
        when ".gif" then "image/gif"
        when ".webp" then "image/webp"
        when ".pdf" then "application/pdf"
        else "application/octet-stream"
        end
      end

      # 顧客の未回収残高を再計算して更新する
      #
      # @param customer [Customer]
      # @return [void]
      def update_customer_outstanding!(customer)
        outstanding = customer.documents.active
                              .where(document_type: "invoice")
                              .where.not(payment_status: "paid")
                              .sum(:remaining_amount)
        customer.update_columns(total_outstanding: outstanding)
      end

      # 銀行明細をシリアライズする
      #
      # @param stmt [BankStatement]
      # @return [Hash]
      def serialize_statement(stmt)
        {
          id: stmt.id,
          transaction_date: stmt.transaction_date,
          description: stmt.description,
          payer_name: stmt.payer_name,
          amount: stmt.amount,
          balance: stmt.balance,
          bank_name: stmt.bank_name,
          is_matched: stmt.is_matched,
          matched_document_uuid: stmt.matched_document&.uuid,
          ai_match_confidence: stmt.ai_match_confidence,
          ai_match_reason: stmt.ai_match_reason,
          import_batch_id: stmt.import_batch_id,
          created_at: stmt.created_at
        }
      end

      # AI提案情報付きでシリアライズする
      #
      # @param stmt [BankStatement]
      # @return [Hash]
      def serialize_statement_with_suggestion(stmt)
        base = serialize_statement(stmt)
        if stmt.ai_suggested_document.present?
          base[:suggestion] = {
            document_uuid: stmt.ai_suggested_document.uuid,
            document_number: stmt.ai_suggested_document.document_number,
            customer_name: stmt.ai_suggested_document.customer&.company_name,
            remaining_amount: stmt.ai_suggested_document.remaining_amount,
            confidence: stmt.ai_match_confidence,
            reason: stmt.ai_match_reason
          }
        end
        base
      end
    end
  end
end
