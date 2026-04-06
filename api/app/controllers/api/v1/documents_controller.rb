# frozen_string_literal: true

module Api
  module V1
    # 帳票を管理するコントローラー
    #
    # 見積書・請求書等のCRUD、ステータス遷移、複製、変換、
    # バージョン管理等の機能を提供する。
    class DocumentsController < BaseController
      before_action :set_document, only: %i[show update destroy duplicate convert approve reject send_document lock pdf versions ai_suggest]

      # ステータス遷移の定義
      TRANSITIONS = {
        "draft" => %w[approved sent],
        "approved" => %w[sent draft],
        "sent" => %w[accepted rejected locked],
        "accepted" => %w[locked],
        "rejected" => %w[draft],
        "cancelled" => [],
        "locked" => []
      }.freeze

      # 帳票変換の許可ルール
      CONVERSIONS = {
        "estimate" => %w[invoice purchase_order],
        "purchase_order" => %w[delivery_note invoice],
        "invoice" => %w[receipt]
      }.freeze

      # 帳票一覧を返す
      #
      # @return [void]
      def index
        documents = policy_scope(Document).active
        documents = apply_filters(documents)
        documents = apply_sort(documents)
        documents = documents.page(page_param).per(per_page_param)

        render json: {
          documents: documents.map { |d| serialize_document(d) },
          meta: pagination_meta(documents)
        }
      end

      # 帳票詳細を返す
      #
      # @return [void]
      def show
        authorize @document
        render json: {
          document: serialize_document_detail(@document)
        }
      end

      # 帳票を新規作成する
      #
      # @return [void]
      def create
        authorize Document
        PlanLimitChecker.new(current_tenant).check!(:documents_monthly)
        document = build_document
        document.save!
        DocumentCalculator.call(document)
        create_version(document, "作成")
        AuditLogger.log(user: current_user, action: "create", resource: document)

        render json: { document: serialize_document_detail(document.reload) }, status: :created
      end

      # 帳票を更新する
      #
      # @return [void]
      def update
        authorize @document
        return unless ensure_not_locked!

        attrs = document_params.except(:customer_id, :project_id)

        # UUID → ID の解決
        if document_params[:customer_id].present?
          @document.customer = policy_scope(Customer).find_by_uuid!(document_params[:customer_id])
        end
        if document_params[:project_id].present?
          @document.project = policy_scope(Project).find_by_uuid!(document_params[:project_id])
        end

        @document.update!(attrs)
        @document.document_items.reload
        DocumentCalculator.call(@document)
        create_version(@document, "更新")
        AuditLogger.log(user: current_user, action: "update", resource: @document)

        render json: { document: serialize_document_detail(@document.reload) }
      end

      # 帳票を論理削除する
      #
      # @return [void]
      def destroy
        authorize @document
        return unless ensure_not_locked!

        @document.soft_delete!
        AuditLogger.log(user: current_user, action: "delete", resource: @document)

        head :no_content
      end

      # 帳票を複製する
      #
      # @return [void]
      def duplicate
        authorize @document
        PlanLimitChecker.new(current_tenant).check!(:documents_monthly)
        dup = duplicate_document(@document)
        AuditLogger.log(user: current_user, action: "create", resource: dup, changes: { source: @document.uuid })

        render json: { document: serialize_document_detail(dup) }, status: :created
      end

      # 帳票を別タイプに変換する
      #
      # @return [void]
      def convert
        authorize @document
        PlanLimitChecker.new(current_tenant).check!(:documents_monthly)
        target_type = params[:target_type]

        converted = DocumentConverter.call(
          @document, target_type,
          user: current_user, tenant: current_tenant
        )
        AuditLogger.log(user: current_user, action: "create", resource: converted,
                        changes: { source: @document.uuid, conversion: "#{@document.document_type}→#{target_type}" })

        render json: { document: serialize_document_detail(converted) }, status: :created
      rescue DocumentConverter::ConversionError => e
        render json: {
          error: { code: "conversion_error", message: e.message }
        }, status: :unprocessable_entity
      end

      # 帳票を承認する
      #
      # @return [void]
      def approve
        authorize @document
        return unless transition_status!("approved")

        # 承認通知（作成者宛）
        if @document.created_by_user.present? && @document.created_by_user != current_user
          Notification.create!(
            tenant: current_tenant,
            user: @document.created_by_user,
            notification_type: "document_approved",
            title: "帳票が承認されました",
            body: "#{@document.document_number}（#{@document.title}）が承認されました。"
          )
        end

        render json: { document: serialize_document(@document) }
      end

      # 帳票を差し戻す
      #
      # @return [void]
      def reject
        authorize @document
        return unless transition_status!("draft")

        render json: { document: serialize_document(@document) }
      end

      # 帳票を送信済みにする
      #
      # メール送信の場合はPDFを生成してDocumentMailerで送信する。
      #
      # @return [void]
      def send_document
        authorize @document
        return unless transition_status!("sent")

        method = params[:method] || "email"
        @document.update!(sent_at: Time.current, sent_method: method)

        if method == "email" && params[:recipient_email].present?
          ensure_pdf_generated!
          DocumentMailer.send_document(
            @document, params[:recipient_email],
            subject: params[:email_subject],
            body: params[:email_body]
          ).deliver_later
        end

        AuditLogger.log(user: current_user, action: "send", resource: @document)
        render json: { document: serialize_document(@document) }
      end

      # 帳票をロックする（電子帳簿保存法対応）
      #
      # @return [void]
      def lock
        authorize @document
        return unless transition_status!("locked")

        @document.update!(locked_at: Time.current)
        AuditLogger.log(user: current_user, action: "lock", resource: @document)
        render json: { document: serialize_document(@document) }
      end

      # PDFを取得する（未生成の場合は同期生成）
      #
      # PdfGeneratorがR2/MinIO署名付きURL（有効期限30分）を直接返す。
      # 既存のpdf_urlは署名期限切れの可能性があるため、毎回再生成する。
      #
      # @return [void]
      def pdf
        authorize @document
        PdfGenerator.call(@document)
        @document.reload

        # 署名付きURLは期限切れの可能性があるため、blobから再生成
        signed_url = fresh_signed_url(@document)

        render json: { pdf_url: signed_url, pdf_generated_at: @document.pdf_generated_at }
      end

      # バージョン履歴を返す
      #
      # @return [void]
      def versions
        authorize @document
        vers = @document.document_versions.order(version: :desc)

        render json: {
          versions: vers.map { |v| serialize_version(v) }
        }
      end

      # AIによる明細行の提案を取得する
      #
      # @return [void]
      def ai_suggest
        authorize @document
        PlanLimitChecker.new(current_tenant).check!(:ai_matching)
        result = AiDocumentSuggester.call(@document)

        render json: {
          suggestions: result[:items],
          confidence: result[:confidence]
        }
      end

      private

      # @return [void]
      def set_document
        @document = policy_scope(Document).active.find_by_uuid!(params[:id])
      end

      # @return [Document] 構築された帳票
      def build_document
        attrs = document_params.except(:document_items_attributes, :customer_id, :project_id)
        doc = Document.new(attrs)
        doc.tenant = current_tenant
        doc.created_by_user = current_user

        # UUID → ID の解決
        if document_params[:customer_id].present?
          doc.customer = policy_scope(Customer).find_by_uuid!(document_params[:customer_id])
        end
        if document_params[:project_id].present?
          doc.project = policy_scope(Project).find_by_uuid!(document_params[:project_id])
        end

        doc.document_number = DocumentNumberGenerator.call(current_tenant, doc.document_type, issue_date: doc.issue_date || Date.current)

        if document_params[:document_items_attributes].present?
          doc.document_items_attributes = document_params[:document_items_attributes].map do |item|
            item.respond_to?(:to_unsafe_h) ? item.to_unsafe_h : item.to_h
          end
        end

        doc
      end

      # @return [ActionController::Parameters]
      def document_params
        params.require(:document).permit(
          :document_type, :customer_id, :project_id,
          :title, :issue_date, :due_date, :valid_until,
          :notes, :internal_memo,
          document_items_attributes: [
            :id, :product_id, :item_type, :name, :description,
            :quantity, :unit, :unit_price, :tax_rate, :tax_rate_type,
            :sort_order, :_destroy
          ]
        )
      end

      # pdf_urlに保存されたblobキーからMinIO/R2署名付きURLを生成する（有効期限30分）
      #
      # pdf_urlは "blob://<key>" 形式で保存されている。
      # 署名計算はブラウザがアクセスする外部URL(localhost:9000)で行う。
      #
      # @param document [Document]
      # @return [String] 署名付きURL
      def fresh_signed_url(document)
        return "" if document.pdf_url.blank?

        blob_key = if document.pdf_url.start_with?("blob://")
                     document.pdf_url.sub("blob://", "")
                   else
                     filename = document.document_number.gsub("/", "_")
                     blob = ActiveStorage::Blob.where("filename LIKE ?", "#{filename}%")
                                               .order(created_at: :desc).first
                     blob&.key
                   end

        return document.pdf_url if blob_key.blank?

        # 署名計算はブラウザからアクセスする外部URLで行う（ホスト名が署名に含まれるため）
        external_endpoint = ENV.fetch("MINIO_EXTERNAL_URL", "http://localhost:9000")
        bucket = ENV.fetch("R2_BUCKET", "uketori-dev")
        client = Aws::S3::Client.new(
          endpoint: external_endpoint,
          access_key_id: ENV.fetch("R2_ACCESS_KEY_ID", "minioadmin"),
          secret_access_key: ENV.fetch("R2_SECRET_ACCESS_KEY", "minioadmin"),
          region: "auto",
          force_path_style: true
        )
        signer = Aws::S3::Presigner.new(client: client)
        signer.presigned_url(:get_object, bucket: bucket, key: blob_key, expires_in: 1800)
      rescue StandardError => e
        Rails.logger.warn("Failed to generate signed URL: #{e.message}")
        raise ActiveRecord::RecordNotFound, "署名付きURLの生成に失敗しました"
      end

      # PDFが未生成の場合に同期生成する
      #
      # @return [void]
      def ensure_pdf_generated!
        return if @document.pdf_url.present?

        PdfGenerator.call(@document)
      end

      # ロック済みチェック
      #
      # @return [Boolean] ロック済みでない場合はtrue、ロック済みの場合はfalse
      def ensure_not_locked!
        return true unless @document.locked?

        render json: {
          error: { code: "locked_error", message: "ロック済みの帳票は変更できません" }
        }, status: :unprocessable_entity
        false
      end

      # ステータス遷移を実行する
      #
      # @param new_status [String] 遷移先ステータス
      # @return [void]
      # @return [Boolean] 遷移成功時はtrue、失敗時はfalse
      def transition_status!(new_status)
        allowed = TRANSITIONS[@document.status] || []
        unless allowed.include?(new_status)
          render json: {
            error: { code: "transition_error", message: "#{@document.status}から#{new_status}への遷移はできません" }
          }, status: :unprocessable_entity
          return false
        end

        @document.update!(status: new_status)
        AuditLogger.log(user: current_user, action: "update", resource: @document,
                        changes: { status_from: @document.status_before_last_save, status_to: new_status })
        true
      end

      # 帳票を複製する
      #
      # @param source [Document] 複製元の帳票
      # @return [Document] 複製された帳票
      def duplicate_document(source)
        ActiveRecord::Base.transaction do
          dup = source.dup
          dup.uuid = nil # auto-generated
          dup.status = "draft"
          dup.document_number = DocumentNumberGenerator.call(current_tenant, source.document_type)
          dup.sent_at = nil
          dup.locked_at = nil
          dup.pdf_url = nil
          dup.pdf_generated_at = nil
          dup.created_by_user = current_user
          dup.save!

          source.document_items.each do |item|
            new_item = item.dup
            new_item.document = dup
            new_item.save!
          end

          DocumentCalculator.call(dup)
          create_version(dup, "複製")
          dup
        end
      end

      # バージョンスナップショットを作成する
      #
      # @param document [Document]
      # @param reason [String] 変更理由
      # @return [DocumentVersion]
      def create_version(document, reason)
        next_version = (document.document_versions.maximum(:version) || 0) + 1
        document.document_versions.create!(
          version: next_version,
          snapshot: document.attributes.except("id").merge(
            items: document.document_items.map(&:attributes)
          ),
          changed_by_user: current_user,
          change_reason: reason
        )
      end

      # フィルタを適用する（電子帳簿保存法対応: 日付・金額・取引先名での検索を含む）
      #
      # @param scope [ActiveRecord::Relation]
      # @return [ActiveRecord::Relation]
      def apply_filters(scope)
        scope = scope.by_type(params.dig(:filter, :document_type)) if params.dig(:filter, :document_type).present?
        scope = scope.where(status: params.dig(:filter, :status)) if params.dig(:filter, :status).present?
        if params.dig(:filter, :payment_status).present?
          statuses = params.dig(:filter, :payment_status).split(",").map(&:strip)
          scope = scope.where(payment_status: statuses)
        end
        if params.dig(:filter, :customer_id).present?
          customer = policy_scope(Customer).find_by_uuid!(params.dig(:filter, :customer_id))
          scope = scope.where(customer_id: customer.id)
        end

        # 電子帳簿保存法: 日付範囲検索
        if params.dig(:filter, :issue_date_from).present?
          scope = scope.where("issue_date >= ?", params.dig(:filter, :issue_date_from))
        end
        if params.dig(:filter, :issue_date_to).present?
          scope = scope.where("issue_date <= ?", params.dig(:filter, :issue_date_to))
        end

        # 電子帳簿保存法: 金額範囲検索
        if params.dig(:filter, :amount_min).present?
          scope = scope.where("total_amount >= ?", params.dig(:filter, :amount_min).to_i)
        end
        if params.dig(:filter, :amount_max).present?
          scope = scope.where("total_amount <= ?", params.dig(:filter, :amount_max).to_i)
        end

        # 電子帳簿保存法: 取引先名検索
        if params.dig(:filter, :customer_name).present?
          scope = scope.joins(:customer).where("customers.company_name ILIKE ?", "%#{params.dig(:filter, :customer_name)}%")
        end

        scope
      end

      # ソートを適用する
      #
      # @param scope [ActiveRecord::Relation]
      # @return [ActiveRecord::Relation]
      def apply_sort(scope)
        sort_col = %w[issue_date created_at total_amount document_number due_date].include?(params[:sort]) ? params[:sort] : "created_at"
        sort_dir = params[:order] == "asc" ? :asc : :desc
        scope.order(sort_col => sort_dir)
      end

      # @param document [Document]
      # @return [Hash] 帳票のサマリー
      def serialize_document(document)
        {
          id: document.uuid,
          document_type: document.document_type,
          document_number: document.document_number,
          status: document.status,
          customer_name: document.customer&.company_name,
          title: document.title,
          total_amount: document.total_amount,
          issue_date: document.issue_date,
          due_date: document.due_date,
          payment_status: document.payment_status,
          created_at: document.created_at
        }
      end

      # @param document [Document]
      # @return [Hash] 帳票の詳細
      def serialize_document_detail(document)
        serialize_document(document).merge(
          customer_id: document.customer&.uuid,
          project_id: document.project&.uuid,
          subtotal_amount: document.subtotal,
          tax_amount: document.tax_amount,
          tax_summary: document.tax_summary,
          remaining_amount: document.remaining_amount,
          paid_amount: document.paid_amount,
          notes: document.notes,
          internal_memo: document.internal_memo,
          valid_until: document.valid_until,
          sender_snapshot: document.sender_snapshot,
          recipient_snapshot: document.recipient_snapshot,
          sent_at: document.sent_at,
          locked_at: document.locked_at,
          version: document.version,
          items: document.document_items.order(:sort_order).map { |i| serialize_item(i) },
          updated_at: document.updated_at
        )
      end

      # @param item [DocumentItem]
      # @return [Hash] 明細行情報
      def serialize_item(item)
        {
          id: item.id,
          product_id: item.product_id,
          item_type: item.item_type,
          name: item.name,
          description: item.description,
          quantity: item.quantity,
          unit: item.unit,
          unit_price: item.unit_price,
          amount: item.amount,
          tax_rate: item.tax_rate,
          tax_rate_type: item.tax_rate_type,
          tax_amount: item.tax_amount,
          sort_order: item.sort_order
        }
      end

      # @param ver [DocumentVersion]
      # @return [Hash] バージョン情報
      def serialize_version(ver)
        {
          id: ver.id,
          version: ver.version,
          change_reason: ver.change_reason,
          changed_by: ver.changed_by_user&.name,
          created_at: ver.created_at
        }
      end
    end
  end
end
