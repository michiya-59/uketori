# 業種テンプレート
IndustryTemplate.find_or_create_by!(code: "general") do |t|
  t.name = "汎用（全業種共通）"
  t.labels = { project: "案件", document: "帳票" }
  t.default_products = [
    { name: "作業費", unit: "式", tax_rate_type: "standard" },
    { name: "消耗品", unit: "個", tax_rate_type: "standard" }
  ]
end

IndustryTemplate.find_or_create_by!(code: "it") do |t|
  t.name = "IT・Web制作業"
  t.labels = { project: "プロジェクト", document: "帳票" }
  t.default_products = [
    { name: "システム設計", unit: "人月", tax_rate_type: "standard" },
    { name: "プログラミング", unit: "時間", tax_rate_type: "standard" },
    { name: "デザイン制作", unit: "式", tax_rate_type: "standard" },
    { name: "サーバー費用", unit: "月", tax_rate_type: "standard" },
    { name: "保守・運用", unit: "月", tax_rate_type: "standard" }
  ]
end

IndustryTemplate.find_or_create_by!(code: "construction") do |t|
  t.name = "建設業"
  t.labels = { project: "工事案件", document: "帳票" }
  t.default_products = [
    { name: "材料費", unit: "式", tax_rate_type: "standard" },
    { name: "労務費", unit: "人工", tax_rate_type: "standard" },
    { name: "外注費", unit: "式", tax_rate_type: "standard" },
    { name: "諸経費", unit: "式", tax_rate_type: "standard" }
  ]
end

IndustryTemplate.find_or_create_by!(code: "design") do |t|
  t.name = "デザイン・クリエイティブ業"
  t.labels = { project: "案件", document: "帳票" }
  t.default_products = [
    { name: "デザイン制作費", unit: "式", tax_rate_type: "standard" },
    { name: "撮影費", unit: "回", tax_rate_type: "standard" },
    { name: "印刷費", unit: "部", tax_rate_type: "standard" },
    { name: "ディレクション費", unit: "式", tax_rate_type: "standard" }
  ]
end

IndustryTemplate.find_or_create_by!(code: "consulting") do |t|
  t.name = "コンサルティング業"
  t.labels = { project: "プロジェクト", document: "帳票" }
  t.default_products = [
    { name: "コンサルティング費", unit: "時間", tax_rate_type: "standard" },
    { name: "顧問料", unit: "月", tax_rate_type: "standard" },
    { name: "調査・分析費", unit: "式", tax_rate_type: "standard" }
  ]
end

IndustryTemplate.find_or_create_by!(code: "legal") do |t|
  t.name = "士業（税理士・社労士等）"
  t.labels = { project: "顧問契約", document: "帳票" }
  t.default_products = [
    { name: "顧問報酬", unit: "月", tax_rate_type: "standard" },
    { name: "決算申告報酬", unit: "式", tax_rate_type: "standard" },
    { name: "年末調整報酬", unit: "式", tax_rate_type: "standard" },
    { name: "スポット相談", unit: "時間", tax_rate_type: "standard" }
  ]
end

# インポートカラム定義（board対応）
[
  { source_column_name: "顧客名", target_table: "customers", target_column: "company_name", is_required: true },
  { source_column_name: "メールアドレス", target_table: "customers", target_column: "email" },
  { source_column_name: "電話番号", target_table: "customers", target_column: "phone" },
  { source_column_name: "案件名", target_table: "projects", target_column: "name", is_required: true },
  { source_column_name: "見積金額", target_table: "documents", target_column: "total_amount", transform_rule: "amount_comma" },
  { source_column_name: "請求金額", target_table: "documents", target_column: "total_amount", transform_rule: "amount_comma" },
  { source_column_name: "請求日", target_table: "documents", target_column: "issue_date", transform_rule: "date_jp" },
  { source_column_name: "支払期日", target_table: "documents", target_column: "due_date", transform_rule: "date_jp" },
  { source_column_name: "入金状況", target_table: "documents", target_column: "payment_status", transform_rule: "status_map" }
].each do |attrs|
  ImportColumnDefinition.find_or_create_by!(
    source_type: "board",
    source_column_name: attrs[:source_column_name]
  ) do |d|
    d.target_table = attrs[:target_table]
    d.target_column = attrs[:target_column]
    d.transform_rule = attrs[:transform_rule]
    d.is_required = attrs[:is_required] || false
  end
end

# 管理者テナント・ユーザー
admin_tenant = Tenant.find_or_create_by!(name: "管理者テナント") do |t|
  t.plan = "professional"
  t.industry_type = "it"
  t.default_tax_rate = 10.0
  t.fiscal_year_start_month = 4
  t.default_payment_terms_days = 30
end

User.find_or_create_by!(email: "nishino.michiya0509@gmail.com") do |u|
  u.tenant = admin_tenant
  u.name = "管理者"
  u.password = "michiya0509"
  u.password_confirmation = "michiya0509"
  u.role = "owner"
  u.system_admin = true
end

Rails.logger.info "Seeds completed: #{IndustryTemplate.count} industry templates, #{ImportColumnDefinition.count} import column definitions, #{User.count} users"

if Rails.env.development?
  # LPスクリーンショット用デモデータ
  #
  # 既存の管理者テナントとは別に、スクリーンショット用途のデモテナントを作成する。
  # このテナント配下の業務データのみを毎回再生成するため、seedを再実行しても状態が安定する。
  DEFAULT_DUNNING_SUBJECT = "【お支払いのお願い】{{document_number}} ({{overdue_days}}日超過)"
  DEFAULT_DUNNING_BODY = <<~TEXT
    {{customer_name}} 御中

    いつもお世話になっております。{{company_name}}です。

    下記請求書のお支払期限が{{overdue_days}}日超過しております。
    お忙しいところ恐れ入りますが、ご確認の上、お早めにお支払いいただけますようお願い申し上げます。

    ■ 請求書番号: {{document_number}}
    ■ 請求金額: {{total_amount}}円
    ■ 未回収金額: {{remaining_amount}}円
    ■ お支払期限: {{due_date}}

    ■ お振込先:
    {{bank_info}}

    何かご不明な点がございましたら、お気軽にお問い合わせください。

    {{company_name}}
  TEXT

  def create_demo_document!(tenant:, customer:, project:, user:, attrs:, items:)
    document = Document.create!(
      {
        tenant: tenant,
        customer: customer,
        project: project,
        created_by_user: user,
        status: "sent",
        sender_snapshot: {
          company_name: tenant.name,
          email: tenant.email,
          phone: tenant.phone
        },
        recipient_snapshot: {
          company_name: customer.company_name,
          email: customer.email,
          phone: customer.phone
        }
      }.merge(attrs)
    )

    items.each_with_index do |item, index|
      document.document_items.create!(
        {
          sort_order: index,
          item_type: "normal",
          quantity: 1,
          unit: "式",
          tax_rate: 10.0,
          tax_rate_type: "standard"
        }.merge(item)
      )
    end

    document.recalculate_amounts!
    document
  end

  def update_customer_outstanding!(customer)
    outstanding = customer.documents.active
                          .where(document_type: "invoice", payment_status: %w[unpaid partial overdue])
                          .sum(:remaining_amount)

    customer.update!(total_outstanding: outstanding)
  end

  demo_tenant = admin_tenant
  demo_tenant.assign_attributes(
    plan: "professional",
    industry_type: "it",
    default_tax_rate: 10.0,
    fiscal_year_start_month: 4,
    default_payment_terms_days: 30,
    dunning_enabled: true,
    import_enabled: true,
    email: "billing-demo@uketori.local",
    phone: "03-6824-1200",
    prefecture: "東京都",
    city: "渋谷区",
    address_line1: "神南1-1-1",
    website: "https://uketori.local",
    bank_name: "みずほ銀行",
    bank_branch_name: "渋谷支店",
    bank_account_type: "ordinary",
    bank_account_number: "1234567",
    bank_account_holder: "カ）エルピースクシヨカクニンヨウデモ"
  )
  demo_tenant.save!

  demo_owner = User.find_by!(tenant: demo_tenant, email: "nishino.michiya0509@gmail.com")

  demo_accountant = User.find_or_initialize_by(tenant: demo_tenant, email: "demo.accounting@uketori.local")
  demo_accountant.assign_attributes(
    name: "経理担当",
    role: "accountant",
    password: "DemoPass!2026",
    password_confirmation: "DemoPass!2026",
    system_admin: false
  )
  demo_accountant.save!

  ActiveRecord::Base.transaction do
  demo_customer_names = [
    "株式会社アルファソリューション",
    "株式会社ベータ物流",
    "ガンマ商事株式会社",
    "株式会社デルタ製作所"
  ]
  demo_project_numbers = %w[PJ-2026-001 PJ-2026-002 PJ-2026-003 PJ-2025-011]
  demo_document_numbers = %w[INV-2026-001 INV-2026-002 INV-2026-003 INV-2026-004 INV-2025-011 EST-2026-015]
  demo_rule_names = ["3日後のやんわり督促", "14日後の再督促", "30日後の最終通知"]
  demo_product_codes = %w[DEV-001 OPS-001 CONS-001 DSGN-001 INT-001]
  demo_import_file_names = ["取引先一覧_2026Q2.xlsx"]
  demo_batch_ids = %w[demo-bank-batch-matched demo-bank-batch-review]

  seeded_customers = Customer.where(tenant: demo_tenant, company_name: demo_customer_names)
  seeded_projects = Project.where(tenant: demo_tenant, project_number: demo_project_numbers)
  seeded_documents = Document.where(tenant: demo_tenant, document_number: demo_document_numbers)
  seeded_rules = DunningRule.where(tenant: demo_tenant, name: demo_rule_names)

  DunningLog.where(
    tenant: demo_tenant,
    document_id: seeded_documents.select(:id)
  ).or(
    DunningLog.where(tenant: demo_tenant, dunning_rule_id: seeded_rules.select(:id))
  ).or(
    DunningLog.where(tenant: demo_tenant, customer_id: seeded_customers.select(:id))
  ).delete_all

  PaymentRecord.where(
    tenant: demo_tenant,
    document_id: seeded_documents.select(:id)
  ).delete_all

  BankStatement.where(
    tenant: demo_tenant,
    import_batch_id: demo_batch_ids
  ).or(
    BankStatement.where(tenant: demo_tenant, matched_document_id: seeded_documents.select(:id))
  ).or(
    BankStatement.where(tenant: demo_tenant, ai_suggested_document_id: seeded_documents.select(:id))
  ).delete_all

  ImportJob.where(tenant: demo_tenant, file_name: demo_import_file_names).delete_all
  seeded_documents.destroy_all
  seeded_projects.destroy_all
  seeded_customers.destroy_all
  Product.where(tenant: demo_tenant, code: demo_product_codes).delete_all
  seeded_rules.delete_all

  products = [
    { code: "DEV-001", name: "システム開発費", unit: "式", unit_price: 220_000, category: "開発" },
    { code: "OPS-001", name: "保守運用費", unit: "月", unit_price: 110_000, category: "保守" },
    { code: "CONS-001", name: "業務改善コンサル", unit: "式", unit_price: 180_000, category: "コンサル" },
    { code: "DSGN-001", name: "デザイン制作費", unit: "式", unit_price: 410_000, category: "制作" },
    { code: "INT-001", name: "基幹連携対応", unit: "式", unit_price: 660_000, category: "開発" }
  ].map.with_index do |attrs, index|
    Product.create!(
      tenant: demo_tenant,
      sort_order: index,
      tax_rate: 10.0,
      is_active: true,
      **attrs
    )
  end

  customers = [
    {
      key: :alpha,
      company_name: "株式会社アルファソリューション",
      company_name_kana: "カブシキガイシャアルファソリューション",
      contact_name: "高橋 亮",
      email: "accounting@alpha.example.jp",
      phone: "03-5100-1001",
      credit_score: 82,
      avg_payment_days: 27.5,
      late_payment_rate: 4.2
    },
    {
      key: :beta,
      company_name: "株式会社ベータ物流",
      company_name_kana: "カブシキガイシャベータブツリュウ",
      contact_name: "木村 麻衣",
      email: "finance@beta.example.jp",
      phone: "06-6200-2202",
      credit_score: 61,
      avg_payment_days: 35.2,
      late_payment_rate: 18.0
    },
    {
      key: :gamma,
      company_name: "ガンマ商事株式会社",
      company_name_kana: "ガンマショウジカブシキガイシャ",
      contact_name: "石田 誠",
      email: "pay@gamma.example.jp",
      phone: "052-220-3303",
      credit_score: 43,
      avg_payment_days: 48.1,
      late_payment_rate: 36.5
    },
    {
      key: :delta,
      company_name: "株式会社デルタ製作所",
      company_name_kana: "カブシキガイシャデルタセイサクショ",
      contact_name: "山口 亜希",
      email: "billing@delta.example.jp",
      phone: "092-410-4404",
      credit_score: 24,
      avg_payment_days: 71.4,
      late_payment_rate: 58.0
    }
  ].each_with_object({}) do |attrs, memo|
    customer = Customer.create!(
      tenant: demo_tenant,
      customer_type: "client",
      payment_terms_days: 30,
      default_tax_rate: 10.0,
      tags: ["lp-demo"],
      **attrs.except(:key)
    )
    customer.customer_contacts.create!(
      name: attrs[:contact_name],
      email: attrs[:email],
      phone: attrs[:phone],
      department: "経理部",
      is_primary: true,
      is_billing_contact: true
    )
    memo[attrs[:key]] = customer
  end

  projects = [
    {
      key: :alpha,
      customer: customers[:alpha],
      project_number: "PJ-2026-001",
      name: "受注管理ダッシュボード改修",
      status: "paid",
      amount: 220_000,
      start_date: Date.current - 30,
      end_date: Date.current - 3
    },
    {
      key: :beta,
      customer: customers[:beta],
      project_number: "PJ-2026-002",
      name: "請求ワークフロー整備",
      status: "partially_paid",
      amount: 330_000,
      start_date: Date.current - 45,
      end_date: Date.current + 10
    },
    {
      key: :gamma,
      customer: customers[:gamma],
      project_number: "PJ-2026-003",
      name: "運用改善コンサルティング",
      status: "overdue",
      amount: 590_000,
      start_date: Date.current - 70,
      end_date: Date.current - 10
    },
    {
      key: :delta,
      customer: customers[:delta],
      project_number: "PJ-2025-011",
      name: "基幹システム連携対応",
      status: "overdue",
      amount: 660_000,
      start_date: Date.current - 160,
      end_date: Date.current - 95
    }
  ].each_with_object({}) do |attrs, memo|
    memo[attrs[:key]] = Project.create!(
      tenant: demo_tenant,
      customer: attrs[:customer],
      assigned_user: demo_accountant,
      description: "LP用のデモ案件です",
      tags: ["lp-demo", attrs[:key].to_s],
      **attrs.except(:key, :customer)
    )
  end

  invoices = {}
  invoices[:alpha_paid] = create_demo_document!(
    tenant: demo_tenant,
    customer: customers[:alpha],
    project: projects[:alpha],
    user: demo_owner,
    attrs: {
      document_type: "invoice",
      document_number: "INV-2026-001",
      title: "ダッシュボード改修 請求書",
      issue_date: Date.current - 18,
      due_date: Date.current - 3
    },
    items: [
      { product: products[0], name: products[0].name, quantity: 1, unit_price: 200_000 },
      { product: products[1], name: "初期運用設定", quantity: 1, unit_price: 20_000 }
    ]
  )

  invoices[:beta_partial] = create_demo_document!(
    tenant: demo_tenant,
    customer: customers[:beta],
    project: projects[:beta],
    user: demo_owner,
    attrs: {
      document_type: "invoice",
      document_number: "INV-2026-002",
      title: "請求ワークフロー整備 請求書",
      issue_date: Date.current - 32,
      due_date: Date.current - 6
    },
    items: [
      { product: products[1], name: products[1].name, quantity: 3, unit_price: 100_000 }
    ]
  )

  invoices[:gamma_current] = create_demo_document!(
    tenant: demo_tenant,
    customer: customers[:gamma],
    project: projects[:gamma],
    user: demo_owner,
    attrs: {
      document_type: "invoice",
      document_number: "INV-2026-003",
      title: "運用改善コンサル 月次請求",
      issue_date: Date.current - 5,
      due_date: Date.current + 7
    },
    items: [
      { product: products[2], name: products[2].name, quantity: 1, unit_price: 180_000 }
    ]
  )

  invoices[:gamma_overdue] = create_demo_document!(
    tenant: demo_tenant,
    customer: customers[:gamma],
    project: projects[:gamma],
    user: demo_owner,
    attrs: {
      document_type: "invoice",
      document_number: "INV-2026-004",
      title: "デザイン制作 一括請求",
      issue_date: Date.current - 58,
      due_date: Date.current - 35
    },
    items: [
      { product: products[3], name: products[3].name, quantity: 1, unit_price: 410_000 }
    ]
  )

  invoices[:delta_overdue] = create_demo_document!(
    tenant: demo_tenant,
    customer: customers[:delta],
    project: projects[:delta],
    user: demo_owner,
    attrs: {
      document_type: "invoice",
      document_number: "INV-2025-011",
      title: "基幹システム連携 請求書",
      issue_date: Date.current - 138,
      due_date: Date.current - 102
    },
    items: [
      { product: products[4], name: products[4].name, quantity: 1, unit_price: 600_000 }
    ]
  )

  estimate = create_demo_document!(
    tenant: demo_tenant,
    customer: customers[:beta],
    project: projects[:beta],
    user: demo_owner,
    attrs: {
      document_type: "estimate",
      document_number: "EST-2026-015",
      status: "approved",
      title: "追加保守見積書",
      issue_date: Date.current - 2,
      valid_until: Date.current + 28
    },
    items: [
      { product: products[1], name: "追加保守作業", quantity: 1, unit_price: 95_000 }
    ]
  )
  estimate.update!(payment_status: nil, remaining_amount: 0, paid_amount: 0)

  invoices[:gamma_overdue].update!(payment_status: "overdue")
  invoices[:delta_overdue].update!(payment_status: "overdue")

  matched_batch = "demo-bank-batch-matched"
  review_batch = "demo-bank-batch-review"

  matched_statement_1 = BankStatement.create!(
    tenant: demo_tenant,
    transaction_date: Date.current - 1,
    value_date: Date.current - 1,
    description: "アルファソリューション 振込",
    payer_name: "アルファソリューション",
    amount: invoices[:alpha_paid].total_amount,
    bank_name: "みずほ銀行",
    account_number: "1234567",
    import_batch_id: matched_batch,
    is_matched: true,
    matched_document: invoices[:alpha_paid],
    ai_suggested_document: invoices[:alpha_paid],
    ai_match_confidence: 0.98,
    ai_match_reason: "請求金額・入金日・振込名義がすべて一致"
  )

  PaymentRecord.create!(
    tenant: demo_tenant,
    document: invoices[:alpha_paid],
    bank_statement: matched_statement_1,
    recorded_by_user: demo_accountant,
    uuid: SecureRandom.uuid,
    amount: invoices[:alpha_paid].total_amount,
    payment_date: matched_statement_1.transaction_date,
    payment_method: "bank_transfer",
    matched_by: "ai_auto",
    match_confidence: 0.98,
    memo: "AI自動消込済み"
  )

  matched_statement_2 = BankStatement.create!(
    tenant: demo_tenant,
    transaction_date: Date.current - 4,
    value_date: Date.current - 4,
    description: "ベータ物流 部分入金",
    payer_name: "ベータブツリュウ",
    amount: 110_000,
    bank_name: "三井住友銀行",
    account_number: "2222000",
    import_batch_id: matched_batch,
    is_matched: true,
    matched_document: invoices[:beta_partial],
    ai_suggested_document: invoices[:beta_partial],
    ai_match_confidence: 0.91,
    ai_match_reason: "金額一致、振込名義が顧客名と高一致"
  )

  PaymentRecord.create!(
    tenant: demo_tenant,
    document: invoices[:beta_partial],
    bank_statement: matched_statement_2,
    recorded_by_user: demo_accountant,
    uuid: SecureRandom.uuid,
    amount: 110_000,
    payment_date: matched_statement_2.transaction_date,
    payment_method: "bank_transfer",
    matched_by: "ai_auto",
    match_confidence: 0.91,
    memo: "初回入金"
  )

  BankStatement.create!(
    tenant: demo_tenant,
    transaction_date: Date.current - 1,
    value_date: Date.current - 1,
    description: "ガンマ商事 定期振込",
    payer_name: "ガンマショウジ",
    amount: invoices[:gamma_current].total_amount,
    bank_name: "楽天銀行",
    account_number: "3030303",
    import_batch_id: review_batch,
    is_matched: false,
    ai_suggested_document: invoices[:gamma_current],
    ai_match_confidence: 0.94,
    ai_match_reason: "金額一致。期日が近く、振込名義の表記揺れも許容範囲"
  )

  BankStatement.create!(
    tenant: demo_tenant,
    transaction_date: Date.current - 2,
    value_date: Date.current - 2,
    description: "デルタ製作所 先行入金候補",
    payer_name: "デルタセイサクショ",
    amount: 330_000,
    bank_name: "三菱UFJ銀行",
    account_number: "4040404",
    import_batch_id: review_batch,
    is_matched: false,
    ai_suggested_document: invoices[:delta_overdue],
    ai_match_confidence: 0.76,
    ai_match_reason: "一部入金の可能性あり。名義一致だが金額が残額と半額差異"
  )

  BankStatement.create!(
    tenant: demo_tenant,
    transaction_date: Date.current - 6,
    value_date: Date.current - 6,
    description: "不明入金",
    payer_name: "カブシキガイシャシンキ",
    amount: 88_000,
    bank_name: "住信SBIネット銀行",
    account_number: "5050505",
    import_batch_id: review_batch,
    is_matched: false,
    ai_match_confidence: 0.22,
    ai_match_reason: "該当する未回収請求が見つかりません"
  )

  gentle_rule = DunningRule.create!(
    tenant: demo_tenant,
    name: "3日後のやんわり督促",
    trigger_days_after_due: 3,
    action_type: "email",
    send_to: "billing_contact",
    email_template_subject: DEFAULT_DUNNING_SUBJECT,
    email_template_body: DEFAULT_DUNNING_BODY,
    max_dunning_count: 3,
    interval_days: 7,
    sort_order: 1
  )

  DunningRule.create!(
    tenant: demo_tenant,
    name: "14日後の再督促",
    trigger_days_after_due: 14,
    action_type: "both",
    send_to: "billing_contact",
    email_template_subject: "【再送】{{document_number}} のお支払い状況をご確認ください",
    email_template_body: DEFAULT_DUNNING_BODY,
    max_dunning_count: 2,
    interval_days: 10,
    sort_order: 2
  )

  final_rule = DunningRule.create!(
    tenant: demo_tenant,
    name: "30日後の最終通知",
    trigger_days_after_due: 30,
    action_type: "both",
    send_to: "custom_email",
    custom_email: "finance-manager@uketori.local",
    email_template_subject: "【最終通知】{{document_number}} のお支払いを至急ご確認ください",
    email_template_body: DEFAULT_DUNNING_BODY,
    max_dunning_count: 1,
    interval_days: 14,
    sort_order: 3
  )

  DunningLog.create!(
    tenant: demo_tenant,
    document: invoices[:gamma_overdue],
    dunning_rule: gentle_rule,
    customer: customers[:gamma],
    action_type: "email",
    sent_to_email: customers[:gamma].email,
    email_subject: gentle_rule.render_subject(
      "document_number" => invoices[:gamma_overdue].document_number,
      "overdue_days" => 7
    ),
    email_body: gentle_rule.render_body(
      "customer_name" => customers[:gamma].company_name,
      "company_name" => demo_tenant.name,
      "document_number" => invoices[:gamma_overdue].document_number,
      "total_amount" => invoices[:gamma_overdue].total_amount,
      "remaining_amount" => invoices[:gamma_overdue].remaining_amount,
      "due_date" => invoices[:gamma_overdue].due_date,
      "overdue_days" => 7,
      "bank_info" => "#{demo_tenant.bank_name} #{demo_tenant.bank_branch_name} #{demo_tenant.bank_account_number}"
    ),
    status: "opened",
    overdue_days: 7,
    remaining_amount: invoices[:gamma_overdue].remaining_amount,
    created_at: 7.days.ago
  )

  DunningLog.create!(
    tenant: demo_tenant,
    document: invoices[:delta_overdue],
    dunning_rule: final_rule,
    customer: customers[:delta],
    action_type: "both",
    sent_to_email: "finance-manager@uketori.local",
    email_subject: final_rule.render_subject(
      "document_number" => invoices[:delta_overdue].document_number,
      "overdue_days" => 30
    ),
    email_body: final_rule.render_body(
      "customer_name" => customers[:delta].company_name,
      "company_name" => demo_tenant.name,
      "document_number" => invoices[:delta_overdue].document_number,
      "total_amount" => invoices[:delta_overdue].total_amount,
      "remaining_amount" => invoices[:delta_overdue].remaining_amount,
      "due_date" => invoices[:delta_overdue].due_date,
      "overdue_days" => 30,
      "bank_info" => "#{demo_tenant.bank_name} #{demo_tenant.bank_branch_name} #{demo_tenant.bank_account_number}"
    ),
    status: "sent",
    overdue_days: 30,
    remaining_amount: invoices[:delta_overdue].remaining_amount,
    created_at: 2.days.ago
  )

  [
    [customers[:alpha], [85, 83, 82]],
    [customers[:beta], [68, 64, 61]],
    [customers[:gamma], [52, 47, 43]],
    [customers[:delta], [39, 31, 24]]
  ].each do |customer, scores|
    scores.each_with_index do |score, index|
      CreditScoreHistory.create!(
        tenant: demo_tenant,
        customer: customer,
        score: score,
        factors: {
          late_payment_rate: customer.late_payment_rate,
          outstanding: customer.total_outstanding
        },
        calculated_at: (2 - index).months.ago.end_of_month
      )
    end
  end

  Customer.where(id: customers.values.map(&:id)).find_each do |customer|
    update_customer_outstanding!(customer)
    customer.update!(credit_score_updated_at: Time.current)
  end

  ImportJob.create!(
    tenant: demo_tenant,
    user: demo_owner,
    source_type: "excel",
    status: "completed",
    file_url: "local://demo/import/customers.xlsx",
    file_name: "取引先一覧_2026Q2.xlsx",
    file_size: 24_576,
    parsed_data: {
      headers: ["会社名", "担当者名", "メールアドレス", "案件名", "請求金額", "支払期日"],
      rows: [
        ["株式会社ノーススター", "佐々木様", "ap@northstar.example.jp", "SFA導入支援", "198000", "2026-04-30"],
        ["有限会社オリオン", "宮本様", "keiri@orion.example.jp", "会計連携設定", "88000", "2026-05-10"]
      ]
    },
    column_mapping: [
      { source: "会社名", target_table: "customers", target_column: "company_name", confidence: 0.99, method: "dictionary" },
      { source: "担当者名", target_table: "customer_contacts", target_column: "name", confidence: 0.95, method: "ai" },
      { source: "メールアドレス", target_table: "customers", target_column: "email", confidence: 0.98, method: "dictionary" },
      { source: "案件名", target_table: "projects", target_column: "name", confidence: 0.92, method: "ai" },
      { source: "請求金額", target_table: "documents", target_column: "total_amount", confidence: 0.89, method: "ai" },
      { source: "支払期日", target_table: "documents", target_column: "due_date", confidence: 0.94, method: "ai" }
    ],
    preview_data: [
      { "company_name" => "株式会社ノーススター", "name" => "佐々木様", "email" => "ap@northstar.example.jp" },
      { "company_name" => "有限会社オリオン", "name" => "宮本様", "email" => "keiri@orion.example.jp" }
    ],
    ai_mapping_confidence: 0.94,
    import_stats: { total_rows: 24, success_count: 24, error_count: 0, skip_count: 0 },
    started_at: 40.minutes.ago,
    completed_at: 37.minutes.ago
  )
  end

  Rails.logger.info "Demo data ready on tenant: #{demo_tenant.name} / owner=#{demo_owner.email}"
end
