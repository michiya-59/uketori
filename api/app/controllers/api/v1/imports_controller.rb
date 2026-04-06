# frozen_string_literal: true

require "csv"

module Api
  module V1
    # データ移行コントローラー
    #
    # ファイルアップロード、AIカラムマッピング、プレビュー、
    # インポート実行、結果取得のエンドポイントを提供する。
    class ImportsController < BaseController
      before_action :set_import_job, only: %i[show preview mapping execute result error_csv]

      # ファイルをアップロードしてインポートジョブを作成する
      #
      # @return [void]
      def create
        authorize ImportJob
        PlanLimitChecker.new(current_tenant).check!(:imports)

        file = params[:file]
        unless file.present?
          return render json: { error: { code: "validation_error", message: "ファイルが指定されていません" } },
                        status: :unprocessable_entity
        end

        source_type = params[:source_type] || detect_source_type(file)
        csv_data = file.read
        parsed = parse_file(csv_data, file.original_filename)
        source_blob = create_source_blob(csv_data, file)

        import_job = current_tenant.import_jobs.create!(
          user: current_user,
          source_type: source_type,
          status: "mapping",
          file_url: "blob://#{source_blob.key}",
          file_name: file.original_filename,
          file_size: csv_data.bytesize,
          parsed_data: parsed
        )
        import_job.source_file.attach(source_blob)

        # AIカラムマッピング実行
        mapping_result = AiColumnMapper.call(parsed["headers"], source_type)
        import_job.update!(
          column_mapping: mapping_result[:mappings],
          ai_mapping_confidence: mapping_result[:overall_confidence]
        )

        AuditLogger.log(
          user: current_user,
          action: "import",
          resource: import_job,
          changes: { source_type: source_type, file_name: file.original_filename }
        )

        render json: { import_job: serialize_job(import_job) }, status: :created
      end

      # インポートジョブの詳細を返す
      #
      # @return [void]
      def show
        authorize @import_job

        render json: { import_job: serialize_job(@import_job) }
      end

      # プレビューデータを返す
      #
      # @return [void]
      def preview
        authorize @import_job

        rows = @import_job.parsed_data["rows"] || []
        headers = @import_job.parsed_data["headers"] || []
        mappings = @import_job.column_mapping || []

        preview_rows = rows.first(10).map do |row|
          mapped = {}
          mappings.each do |m|
            source = m["source"] || m[:source]
            target = m["target_column"] || m[:target_column]
            idx = headers.index(source)
            mapped[target || source] = idx ? row[idx] : nil
          end
          mapped
        end

        @import_job.update!(status: "previewing", preview_data: preview_rows)

        render json: {
          preview: preview_rows,
          total_rows: rows.size,
          mappings: mappings
        }
      end

      # カラムマッピングを更新する
      #
      # @return [void]
      def mapping
        authorize @import_job

        new_mappings = params.require(:mappings)
        @import_job.update!(column_mapping: new_mappings.map(&:to_unsafe_h))

        render json: { import_job: serialize_job(@import_job) }
      end

      # インポートを実行する
      #
      # @return [void]
      def execute
        authorize @import_job

        unless %w[mapping previewing].include?(@import_job.status)
          return render json: { error: { code: "invalid_status", message: "実行可能な状態ではありません" } },
                        status: :unprocessable_entity
        end

        ImportExecutionJob.perform_later(@import_job.id)

        render json: { import_job: serialize_job(@import_job.reload) }
      end

      # インポート結果を返す
      #
      # @return [void]
      def result
        authorize @import_job

        render json: {
          import_job: serialize_job(@import_job),
          stats: @import_job.import_stats,
          errors: @import_job.error_details
        }
      end

      # エラー詳細をCSVとしてダウンロードする
      #
      # @return [void]
      def error_csv
        authorize @import_job

        errors = @import_job.error_details || []
        if errors.empty?
          return render json: { error: { code: "no_errors", message: "エラーデータがありません" } },
                        status: :not_found
        end

        csv_data = CSV.generate(force_quotes: true) do |csv|
          csv << %w[行番号 エラー内容 データ]
          errors.each do |err|
            csv << [
              err["row_number"] || err[:row_number],
              err["message"] || err[:message],
              (err["data"] || err[:data])&.to_json
            ]
          end
        end

        send_data csv_data,
                  filename: "import_errors_#{@import_job.uuid}.csv",
                  type: "text/csv; charset=utf-8",
                  disposition: "attachment"
      end

      private

      # インポートジョブを取得する
      #
      # @return [void]
      def set_import_job
        @import_job = policy_scope(ImportJob).find_by_uuid!(params[:id])
      end

      # ソースタイプを自動判定する
      #
      # @param file [ActionDispatch::Http::UploadedFile]
      # @return [String]
      def detect_source_type(file)
        ext = File.extname(file.original_filename).downcase
        case ext
        when ".xlsx", ".xls" then "excel"
        when ".csv" then "csv_generic"
        else "csv_generic"
        end
      end

      # ファイルをパースする
      #
      # @param data [String] ファイルデータ
      # @param filename [String] ファイル名
      # @return [Hash] { "headers" => Array, "rows" => Array }
      def parse_file(data, filename)
        csv_data = ensure_utf8(data)
        rows = CSV.parse(csv_data)

        return { "headers" => [], "rows" => [] } if rows.empty?

        headers = rows.first.map { |h| h&.strip || "" }
        data_rows = rows[1..].map { |row| row.map { |cell| cell&.strip || "" } }

        { "headers" => headers, "rows" => data_rows }
      rescue CSV::MalformedCSVError => e
        raise ActionController::BadRequest, "CSVの解析に失敗しました: #{e.message}"
      end

      # UTF-8エンコーディングを保証する
      #
      # @param data [String]
      # @return [String]
      def ensure_utf8(data)
        data = data.dup
        return data if data.encoding == Encoding::UTF_8 && data.valid_encoding?

        data.force_encoding("Shift_JIS")
        data.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
      rescue Encoding::UndefinedConversionError
        data.force_encoding("UTF-8")
        data.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
      end

      # 元ファイルをActiveStorageへ保存する
      #
      # @param data [String]
      # @param file [ActionDispatch::Http::UploadedFile]
      # @return [ActiveStorage::Blob]
      def create_source_blob(data, file)
        ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new(data),
          filename: file.original_filename,
          content_type: file.content_type.presence || "application/octet-stream"
        )
      end

      # インポートジョブをシリアライズする
      #
      # @param job [ImportJob]
      # @return [Hash]
      def serialize_job(job)
        {
          uuid: job.uuid,
          source_type: job.source_type,
          status: job.status,
          file_url: job.source_file_url,
          file_name: job.file_name,
          file_size: job.file_size,
          column_mapping: job.column_mapping,
          ai_mapping_confidence: job.ai_mapping_confidence,
          import_stats: job.import_stats,
          error_details: job.error_details,
          started_at: job.started_at,
          completed_at: job.completed_at,
          created_at: job.created_at
        }
      end
    end
  end
end
