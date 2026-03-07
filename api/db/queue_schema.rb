# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_03_05_101443) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "user_id"
    t.string "action", limit: 50, null: false
    t.string "resource_type", limit: 50, null: false
    t.bigint "resource_id"
    t.jsonb "changes_data"
    t.inet "ip_address"
    t.string "user_agent", limit: 500
    t.datetime "created_at", null: false
    t.index ["tenant_id"], name: "index_audit_logs_on_tenant_id"
  end

  create_table "bank_statements", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.date "transaction_date", null: false
    t.date "value_date"
    t.string "description", limit: 500, null: false
    t.string "payer_name", limit: 255
    t.bigint "amount", null: false
    t.bigint "balance"
    t.string "bank_name", limit: 100
    t.string "account_number", limit: 20
    t.boolean "is_matched", default: false, null: false
    t.bigint "matched_document_id"
    t.bigint "ai_suggested_document_id"
    t.decimal "ai_match_confidence", precision: 3, scale: 2
    t.text "ai_match_reason"
    t.string "import_batch_id", limit: 50, null: false
    t.jsonb "raw_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["import_batch_id"], name: "index_bank_statements_on_import_batch_id"
    t.index ["tenant_id", "is_matched", "transaction_date"], name: "idx_on_tenant_id_is_matched_transaction_date_ffdc7f7ef9", where: "(is_matched = false)"
    t.index ["tenant_id", "transaction_date"], name: "index_bank_statements_on_tenant_id_and_transaction_date"
    t.index ["tenant_id"], name: "index_bank_statements_on_tenant_id"
  end

  create_table "credit_score_histories", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "customer_id", null: false
    t.integer "score", null: false
    t.jsonb "factors", default: "{}", null: false
    t.datetime "calculated_at", null: false
    t.index ["customer_id"], name: "index_credit_score_histories_on_customer_id"
    t.index ["tenant_id"], name: "index_credit_score_histories_on_tenant_id"
  end

  create_table "customer_contacts", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "name", limit: 100, null: false
    t.string "email", limit: 255
    t.string "phone", limit: 20
    t.string "department", limit: 100
    t.string "title", limit: 50
    t.boolean "is_primary", default: false, null: false
    t.boolean "is_billing_contact", default: false, null: false
    t.text "memo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_customer_contacts_on_customer_id"
  end

  create_table "customers", force: :cascade do |t|
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "tenant_id", null: false
    t.string "customer_type", limit: 10, default: "client", null: false
    t.string "company_name", limit: 255, null: false
    t.string "company_name_kana", limit: 255
    t.string "department", limit: 100
    t.string "title", limit: 50
    t.string "contact_name", limit: 100
    t.string "email", limit: 255
    t.string "phone", limit: 20
    t.string "fax", limit: 20
    t.string "postal_code", limit: 8
    t.string "prefecture", limit: 10
    t.string "city", limit: 100
    t.string "address_line1", limit: 255
    t.string "address_line2", limit: 255
    t.string "invoice_registration_number", limit: 14
    t.boolean "invoice_number_verified", default: false, null: false
    t.datetime "invoice_number_verified_at"
    t.integer "payment_terms_days"
    t.decimal "default_tax_rate", precision: 5, scale: 2
    t.string "bank_name", limit: 100
    t.string "bank_branch_name", limit: 100
    t.integer "bank_account_type", limit: 2
    t.string "bank_account_number", limit: 10
    t.string "bank_account_holder", limit: 100
    t.jsonb "tags", default: "[]", null: false
    t.text "memo"
    t.integer "credit_score"
    t.datetime "credit_score_updated_at"
    t.decimal "avg_payment_days", precision: 5, scale: 1
    t.decimal "late_payment_rate", precision: 5, scale: 2
    t.bigint "total_outstanding", default: 0, null: false
    t.string "imported_from", limit: 50
    t.string "external_id", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["tenant_id", "credit_score"], name: "index_customers_on_tenant_id_and_credit_score"
    t.index ["tenant_id", "deleted_at"], name: "index_customers_on_tenant_id_and_deleted_at"
    t.index ["tenant_id", "imported_from", "external_id"], name: "index_customers_on_tenant_id_and_imported_from_and_external_id"
    t.index ["tenant_id", "total_outstanding"], name: "index_customers_on_tenant_id_and_total_outstanding", order: { total_outstanding: :desc }
    t.index ["tenant_id"], name: "index_customers_on_tenant_id"
    t.index ["uuid"], name: "index_customers_on_uuid", unique: true
  end

  create_table "document_items", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.bigint "product_id"
    t.integer "sort_order", default: 0, null: false
    t.string "item_type", limit: 10, default: "normal", null: false
    t.string "name", limit: 255, null: false
    t.text "description"
    t.decimal "quantity", precision: 15, scale: 4, default: "1.0", null: false
    t.string "unit", limit: 20
    t.bigint "unit_price", default: 0, null: false
    t.bigint "amount", default: 0, null: false
    t.decimal "tax_rate", precision: 5, scale: 2, default: "10.0", null: false
    t.string "tax_rate_type", limit: 20, default: "standard", null: false
    t.bigint "tax_amount", default: 0, null: false
    t.index ["document_id"], name: "index_document_items_on_document_id"
    t.index ["product_id"], name: "index_document_items_on_product_id"
  end

  create_table "document_versions", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.integer "version", null: false
    t.jsonb "snapshot", null: false
    t.string "pdf_url", limit: 500
    t.bigint "changed_by_user_id", null: false
    t.text "change_reason"
    t.datetime "created_at", null: false
    t.index ["document_id"], name: "index_document_versions_on_document_id"
  end

  create_table "documents", force: :cascade do |t|
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "tenant_id", null: false
    t.bigint "project_id"
    t.bigint "customer_id", null: false
    t.bigint "created_by_user_id", null: false
    t.string "document_type", limit: 20, null: false
    t.string "document_number", limit: 50, null: false
    t.string "status", limit: 20, default: "draft", null: false
    t.integer "version", default: 1, null: false
    t.bigint "parent_document_id"
    t.string "title", limit: 255
    t.date "issue_date", null: false
    t.date "due_date"
    t.date "valid_until"
    t.bigint "subtotal", default: 0, null: false
    t.bigint "tax_amount", default: 0, null: false
    t.bigint "total_amount", default: 0, null: false
    t.jsonb "tax_summary", default: "[]", null: false
    t.text "notes"
    t.text "internal_memo"
    t.jsonb "sender_snapshot", default: "{}", null: false
    t.jsonb "recipient_snapshot", default: "{}", null: false
    t.string "pdf_url", limit: 500
    t.datetime "pdf_generated_at"
    t.datetime "sent_at"
    t.string "sent_method", limit: 20
    t.datetime "locked_at"
    t.string "payment_status", limit: 20
    t.bigint "paid_amount", default: 0, null: false
    t.bigint "remaining_amount", default: 0, null: false
    t.datetime "last_dunning_at"
    t.integer "dunning_count", default: 0, null: false
    t.boolean "is_recurring", default: false, null: false
    t.bigint "recurring_rule_id"
    t.string "imported_from", limit: 50
    t.string "external_id", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["customer_id"], name: "index_documents_on_customer_id"
    t.index ["project_id"], name: "index_documents_on_project_id"
    t.index ["tenant_id", "document_type", "deleted_at"], name: "index_documents_on_tenant_id_and_document_type_and_deleted_at"
    t.index ["tenant_id", "document_type", "document_number"], name: "idx_on_tenant_id_document_type_document_number_42bd9c3139", unique: true, where: "(deleted_at IS NULL)"
    t.index ["tenant_id", "due_date"], name: "index_documents_on_tenant_id_and_due_date", where: "(((document_type)::text = 'invoice'::text) AND ((payment_status)::text = ANY ((ARRAY['unpaid'::character varying, 'partial'::character varying, 'overdue'::character varying])::text[])))"
    t.index ["tenant_id", "imported_from", "external_id"], name: "index_documents_on_tenant_id_and_imported_from_and_external_id"
    t.index ["tenant_id", "payment_status", "due_date"], name: "index_documents_on_tenant_id_and_payment_status_and_due_date", where: "((document_type)::text = 'invoice'::text)"
    t.index ["tenant_id"], name: "index_documents_on_tenant_id"
    t.index ["uuid"], name: "index_documents_on_uuid", unique: true
  end

  create_table "dunning_logs", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "document_id", null: false
    t.bigint "dunning_rule_id", null: false
    t.bigint "customer_id", null: false
    t.string "action_type", limit: 20, null: false
    t.string "sent_to_email", limit: 255
    t.string "email_subject", limit: 255
    t.text "email_body"
    t.string "status", limit: 20, null: false
    t.integer "overdue_days", null: false
    t.bigint "remaining_amount", null: false
    t.datetime "created_at", null: false
    t.index ["customer_id"], name: "index_dunning_logs_on_customer_id"
    t.index ["document_id"], name: "index_dunning_logs_on_document_id"
    t.index ["dunning_rule_id"], name: "index_dunning_logs_on_dunning_rule_id"
    t.index ["tenant_id"], name: "index_dunning_logs_on_tenant_id"
  end

  create_table "dunning_rules", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "name", limit: 100, null: false
    t.integer "trigger_days_after_due", null: false
    t.string "action_type", limit: 20, null: false
    t.string "email_template_subject", limit: 255
    t.text "email_template_body"
    t.string "send_to", limit: 20, default: "billing_contact", null: false
    t.string "custom_email", limit: 255
    t.boolean "is_active", default: true, null: false
    t.integer "sort_order", default: 0, null: false
    t.integer "max_dunning_count", default: 3, null: false
    t.integer "interval_days", default: 7, null: false
    t.bigint "escalation_rule_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_dunning_rules_on_tenant_id"
  end

  create_table "import_column_definitions", force: :cascade do |t|
    t.string "source_type", limit: 30, null: false
    t.string "source_column_name", limit: 255, null: false
    t.string "target_table", limit: 50, null: false
    t.string "target_column", limit: 50, null: false
    t.string "transform_rule", limit: 50
    t.boolean "is_required", default: false, null: false
  end

  create_table "import_jobs", force: :cascade do |t|
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "tenant_id", null: false
    t.bigint "user_id", null: false
    t.string "source_type", limit: 30, null: false
    t.string "status", limit: 20, default: "pending", null: false
    t.string "file_url", limit: 500, null: false
    t.string "file_name", limit: 255, null: false
    t.bigint "file_size", null: false
    t.jsonb "parsed_data"
    t.jsonb "column_mapping"
    t.jsonb "preview_data"
    t.jsonb "import_stats"
    t.jsonb "error_details"
    t.decimal "ai_mapping_confidence", precision: 3, scale: 2
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_import_jobs_on_tenant_id"
    t.index ["user_id"], name: "index_import_jobs_on_user_id"
  end

  create_table "industry_templates", force: :cascade do |t|
    t.string "code", limit: 50, null: false
    t.string "name", limit: 100, null: false
    t.jsonb "labels", default: "{}", null: false
    t.jsonb "default_products", default: "[]", null: false
    t.jsonb "default_statuses", default: "[]", null: false
    t.jsonb "document_templates", default: "{}", null: false
    t.jsonb "tax_settings", default: "{}", null: false
    t.integer "sort_order", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.index ["code"], name: "index_industry_templates_on_code", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "user_id", null: false
    t.string "notification_type", limit: 50, null: false
    t.string "title", limit: 255, null: false
    t.text "body"
    t.jsonb "data", default: "{}", null: false
    t.boolean "is_read", default: false, null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.index ["tenant_id"], name: "index_notifications_on_tenant_id"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "payment_records", force: :cascade do |t|
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "tenant_id", null: false
    t.bigint "document_id", null: false
    t.bigint "bank_statement_id"
    t.bigint "amount", null: false
    t.date "payment_date", null: false
    t.string "payment_method", limit: 20, default: "bank_transfer", null: false
    t.string "matched_by", limit: 20, default: "manual", null: false
    t.decimal "match_confidence", precision: 3, scale: 2
    t.text "memo"
    t.bigint "recorded_by_user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bank_statement_id"], name: "index_payment_records_on_bank_statement_id"
    t.index ["document_id"], name: "index_payment_records_on_document_id"
    t.index ["tenant_id", "payment_date"], name: "index_payment_records_on_tenant_id_and_payment_date"
    t.index ["tenant_id"], name: "index_payment_records_on_tenant_id"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "code", limit: 50
    t.string "name", limit: 255, null: false
    t.text "description"
    t.string "unit", limit: 20
    t.bigint "unit_price"
    t.decimal "tax_rate", precision: 5, scale: 2
    t.string "tax_rate_type", limit: 20, default: "standard", null: false
    t.string "category", limit: 100
    t.integer "sort_order", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_products_on_tenant_id"
  end

  create_table "projects", force: :cascade do |t|
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "tenant_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "assigned_user_id"
    t.string "project_number", limit: 50, null: false
    t.string "name", limit: 255, null: false
    t.string "status", limit: 30, default: "negotiation", null: false
    t.integer "probability"
    t.bigint "amount"
    t.bigint "cost"
    t.date "start_date"
    t.date "end_date"
    t.text "description"
    t.jsonb "tags", default: "[]", null: false
    t.jsonb "custom_fields", default: "{}", null: false
    t.string "imported_from", limit: 50
    t.string "external_id", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["assigned_user_id"], name: "index_projects_on_assigned_user_id"
    t.index ["customer_id"], name: "index_projects_on_customer_id"
    t.index ["tenant_id", "project_number"], name: "index_projects_on_tenant_id_and_project_number", unique: true, where: "(deleted_at IS NULL)"
    t.index ["tenant_id", "status", "deleted_at"], name: "index_projects_on_tenant_id_and_status_and_deleted_at"
    t.index ["tenant_id"], name: "index_projects_on_tenant_id"
    t.index ["uuid"], name: "index_projects_on_uuid", unique: true
  end

  create_table "recurring_rules", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "project_id"
    t.string "name", limit: 255, null: false
    t.string "frequency", limit: 10, default: "monthly", null: false
    t.integer "generation_day", default: 1, null: false
    t.integer "issue_day", default: 1, null: false
    t.date "next_generation_date", null: false
    t.jsonb "template_items", default: "[]", null: false
    t.boolean "auto_send", default: false, null: false
    t.boolean "is_active", default: true, null: false
    t.date "start_date", null: false
    t.date "end_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_recurring_rules_on_customer_id"
    t.index ["project_id"], name: "index_recurring_rules_on_project_id"
    t.index ["tenant_id"], name: "index_recurring_rules_on_tenant_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "tenants", force: :cascade do |t|
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.string "name", limit: 255, null: false
    t.string "name_kana", limit: 255
    t.string "postal_code", limit: 8
    t.string "prefecture", limit: 10
    t.string "city", limit: 100
    t.string "address_line1", limit: 255
    t.string "address_line2", limit: 255
    t.string "phone", limit: 20
    t.string "fax", limit: 20
    t.string "email", limit: 255
    t.string "website", limit: 500
    t.string "invoice_registration_number", limit: 14
    t.boolean "invoice_number_verified", default: false, null: false
    t.datetime "invoice_number_verified_at"
    t.string "logo_url", limit: 500
    t.string "seal_url", limit: 500
    t.string "bank_name", limit: 100
    t.string "bank_branch_name", limit: 100
    t.integer "bank_account_type", limit: 2
    t.string "bank_account_number", limit: 10
    t.string "bank_account_holder", limit: 100
    t.string "industry_type", limit: 50, default: "general", null: false
    t.integer "fiscal_year_start_month", limit: 2, default: 4, null: false
    t.string "plan", limit: 30, default: "free", null: false
    t.datetime "plan_started_at"
    t.string "stripe_customer_id", limit: 100
    t.string "stripe_subscription_id", limit: 100
    t.string "document_sequence_format", limit: 100, default: "{prefix}-{YYYY}{MM}-{SEQ}", null: false
    t.integer "default_payment_terms_days", default: 30, null: false
    t.decimal "default_tax_rate", precision: 5, scale: 2, default: "10.0", null: false
    t.boolean "dunning_enabled", default: false, null: false
    t.string "timezone", limit: 50, default: "Asia/Tokyo", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.boolean "import_enabled", default: false, null: false
    t.index ["deleted_at"], name: "index_tenants_on_deleted_at"
    t.index ["stripe_customer_id"], name: "index_tenants_on_stripe_customer_id"
    t.index ["uuid"], name: "index_tenants_on_uuid", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "tenant_id", null: false
    t.string "email", limit: 255, null: false
    t.string "password_digest", limit: 255, null: false
    t.string "name", limit: 100, null: false
    t.string "role", limit: 20, default: "member", null: false
    t.string "avatar_url", limit: 500
    t.datetime "last_sign_in_at"
    t.integer "sign_in_count", default: 0, null: false
    t.string "invitation_token", limit: 100
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.string "password_reset_token", limit: 100
    t.datetime "password_reset_sent_at"
    t.boolean "two_factor_enabled", default: false, null: false
    t.string "otp_secret", limit: 100
    t.string "jti", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["tenant_id", "email"], name: "index_users_on_tenant_id_and_email", unique: true, where: "(deleted_at IS NULL)"
    t.index ["tenant_id"], name: "index_users_on_tenant_id"
    t.index ["uuid"], name: "index_users_on_uuid", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_logs", "tenants"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "bank_statements", "documents", column: "matched_document_id"
  add_foreign_key "bank_statements", "tenants"
  add_foreign_key "credit_score_histories", "customers"
  add_foreign_key "credit_score_histories", "tenants"
  add_foreign_key "customer_contacts", "customers"
  add_foreign_key "customers", "tenants"
  add_foreign_key "document_items", "documents"
  add_foreign_key "document_items", "products"
  add_foreign_key "document_versions", "documents"
  add_foreign_key "document_versions", "users", column: "changed_by_user_id"
  add_foreign_key "documents", "customers"
  add_foreign_key "documents", "documents", column: "parent_document_id"
  add_foreign_key "documents", "projects"
  add_foreign_key "documents", "recurring_rules"
  add_foreign_key "documents", "tenants"
  add_foreign_key "documents", "users", column: "created_by_user_id"
  add_foreign_key "dunning_logs", "customers"
  add_foreign_key "dunning_logs", "documents"
  add_foreign_key "dunning_logs", "dunning_rules"
  add_foreign_key "dunning_logs", "tenants"
  add_foreign_key "dunning_rules", "dunning_rules", column: "escalation_rule_id"
  add_foreign_key "dunning_rules", "tenants"
  add_foreign_key "import_jobs", "tenants"
  add_foreign_key "import_jobs", "users"
  add_foreign_key "notifications", "tenants"
  add_foreign_key "notifications", "users"
  add_foreign_key "payment_records", "documents"
  add_foreign_key "payment_records", "tenants"
  add_foreign_key "payment_records", "users", column: "recorded_by_user_id"
  add_foreign_key "products", "tenants"
  add_foreign_key "projects", "customers"
  add_foreign_key "projects", "tenants"
  add_foreign_key "projects", "users", column: "assigned_user_id"
  add_foreign_key "recurring_rules", "customers"
  add_foreign_key "recurring_rules", "projects"
  add_foreign_key "recurring_rules", "tenants"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "users", "tenants"
end
