# frozen_string_literal: true

module Api
  module V1
    # 案件を管理するコントローラー
    #
    # 案件のCRUD操作、ステータス遷移、関連帳票一覧、
    # パイプライン集計の機能を提供する。
    class ProjectsController < BaseController
      before_action :set_project, only: %i[show update destroy status documents]

      # 案件一覧を返す
      #
      # @return [void]
      def index
        projects = policy_scope(Project).active
        projects = apply_filters(projects)
        projects = apply_sort(projects)
        projects = projects.includes(:customer, :assigned_user)
                           .page(page_param).per(per_page_param)

        render json: {
          projects: projects.map { |p| serialize_project(p) },
          meta: pagination_meta(projects)
        }
      end

      # 案件詳細を返す
      #
      # @return [void]
      def show
        authorize @project
        render json: {
          project: serialize_project_detail(@project)
        }
      end

      # 案件を新規作成する
      #
      # @return [void]
      def create
        authorize Project
        project = Project.new(project_params_for_create)
        project.tenant = current_tenant
        project.project_number = generate_project_number
        resolve_associations(project)
        project.save!
        AuditLogger.log(user: current_user, action: "create", resource: project)

        render json: { project: serialize_project(project) }, status: :created
      end

      # 案件情報を更新する
      #
      # @return [void]
      def update
        authorize @project
        attrs = project_params.to_h
        resolve_associations_for_update(@project, attrs)
        @project.update!(attrs)
        AuditLogger.log(user: current_user, action: "update", resource: @project)

        render json: { project: serialize_project_detail(@project.reload) }
      end

      # 案件を論理削除する
      #
      # @return [void]
      def destroy
        authorize @project
        @project.soft_delete!
        AuditLogger.log(user: current_user, action: "delete", resource: @project)

        head :no_content
      end

      # 案件のステータスを遷移させる
      #
      # @return [void]
      def status
        authorize @project
        @project.transition_to!(params[:status])
        AuditLogger.log(user: current_user, action: "update", resource: @project,
                        changes: { status_from: @project.status_before_last_save, status_to: @project.status })

        render json: { project: serialize_project(@project) }
      end

      # 案件に紐づく帳票一覧を返す
      #
      # @return [void]
      def documents
        authorize @project
        docs = @project.documents.active
                       .order(issue_date: :desc)
                       .page(page_param).per(per_page_param)

        render json: {
          documents: docs.map { |d| serialize_document_summary(d) },
          meta: pagination_meta(docs)
        }
      end

      # パイプライン集計を返す
      #
      # @return [void]
      def pipeline
        authorize Project
        scope = policy_scope(Project).active

        pipeline_data = scope.group(:status)
                             .select("status, COUNT(*) as project_count, COALESCE(SUM(amount), 0) as total_amount")
                             .map do |row|
          {
            status: row.status,
            count: row.project_count,
            total_amount: row.total_amount
          }
        end

        render json: { pipeline: pipeline_data }
      end

      private

      # @return [void]
      def set_project
        @project = policy_scope(Project).active.find_by_uuid!(params[:id])
      end

      # @return [ActionController::Parameters]
      def project_params
        params.require(:project).permit(
          :name, :customer_id, :assigned_user_id,
          :probability, :amount, :cost,
          :start_date, :end_date, :description
        )
      end

      # @return [ActionController::Parameters] 作成用パラメータ（association IDを除く）
      def project_params_for_create
        project_params.except(:customer_id, :assigned_user_id)
      end

      # UUID→IDの解決を行い、associationをセットする（作成時）
      #
      # @param project [Project] 対象の案件
      # @return [void]
      def resolve_associations(project)
        if project_params[:customer_id].present?
          project.customer = policy_scope(Customer).find_by_uuid!(project_params[:customer_id])
        end
        if project_params[:assigned_user_id].present?
          project.assigned_user = current_tenant.users.find_by!(uuid: project_params[:assigned_user_id])
        end
      end

      # UUID→IDの解決を行い、attrsハッシュを更新する（更新時）
      #
      # @param project [Project] 対象の案件
      # @param attrs [Hash] 更新パラメータハッシュ
      # @return [void]
      def resolve_associations_for_update(project, attrs)
        if attrs.key?("customer_id") && attrs["customer_id"].present?
          customer = policy_scope(Customer).find_by_uuid!(attrs.delete("customer_id"))
          attrs["customer_id"] = customer.id
        end
        if attrs.key?("assigned_user_id") && attrs["assigned_user_id"].present?
          user = current_tenant.users.find_by!(uuid: attrs.delete("assigned_user_id"))
          attrs["assigned_user_id"] = user.id
        elsif attrs.key?("assigned_user_id")
          attrs.delete("assigned_user_id")
        end
      end

      # 案件番号を自動採番する
      #
      # @return [String] PJ-YYYYMM-NNNN形式の案件番号
      def generate_project_number
        prefix = "PJ-#{Date.current.strftime('%Y%m')}-"
        last_number = current_tenant.projects
                                    .where("project_number LIKE ?", "#{prefix}%")
                                    .order(project_number: :desc)
                                    .limit(1)
                                    .pluck(:project_number)
                                    .first
        seq = if last_number
                last_number.split("-").last.to_i + 1
              else
                1
              end
        "#{prefix}#{seq.to_s.rjust(4, '0')}"
      end

      # @param scope [ActiveRecord::Relation]
      # @return [ActiveRecord::Relation] フィルタ適用済みのスコープ
      def apply_filters(scope)
        if params.dig(:filter, :q).present?
          scope = scope.where("projects.name ILIKE ?", "%#{params.dig(:filter, :q)}%")
        end
        scope = scope.where(status: params.dig(:filter, :status)) if params.dig(:filter, :status).present?
        if params.dig(:filter, :customer_id).present?
          customer = policy_scope(Customer).find_by_uuid!(params.dig(:filter, :customer_id))
          scope = scope.where(customer_id: customer.id)
        end
        scope
      end

      # @param scope [ActiveRecord::Relation]
      # @return [ActiveRecord::Relation] ソート適用済みのスコープ
      def apply_sort(scope)
        sort_column = %w[name created_at amount status].include?(params[:sort]) ? params[:sort] : "created_at"
        sort_order = params[:order] == "asc" ? :asc : :desc
        scope.order(sort_column => sort_order)
      end

      # @param project [Project]
      # @return [Hash] 案件の基本情報
      def serialize_project(project)
        {
          id: project.uuid,
          project_number: project.project_number,
          name: project.name,
          status: project.status,
          customer_id: project.customer&.uuid,
          customer_name: project.customer&.company_name,
          assigned_user_id: project.assigned_user&.uuid,
          assigned_user_name: project.assigned_user&.name,
          probability: project.probability,
          amount: project.amount,
          cost: project.cost,
          start_date: project.start_date,
          end_date: project.end_date,
          created_at: project.created_at
        }
      end

      # @param project [Project]
      # @return [Hash] 案件の詳細情報
      def serialize_project_detail(project)
        serialize_project(project).merge(
          description: project.description,
          updated_at: project.updated_at
        )
      end

      # @param doc [Document]
      # @return [Hash] 帳票サマリー情報
      def serialize_document_summary(doc)
        {
          id: doc.uuid,
          document_type: doc.document_type,
          document_number: doc.document_number,
          status: doc.status,
          total_amount: doc.total_amount,
          issue_date: doc.issue_date,
          due_date: doc.due_date,
          payment_status: doc.payment_status
        }
      end
    end
  end
end
