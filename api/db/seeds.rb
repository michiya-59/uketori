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

Rails.logger.info "Seeds completed: #{IndustryTemplate.count} industry templates, #{ImportColumnDefinition.count} import column definitions"
