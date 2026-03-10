# ウケトリ データベース設計書

## 概要

ウケトリは マルチテナント型SaaS のため、ほぼ全てのテーブルが `tenant_id` を持ち、テナント（契約企業）単位でデータが分離されています。

全 **20 テーブル**（+ ActiveStorage 3テーブル + SolidQueue 11テーブル）

---

## テーブル一覧


| #   | テーブル名                     | 機能領域  | 概要                  |
| --- | ------------------------- | ----- | ------------------- |
| 1   | tenants                   | 基盤    | 契約企業（テナント）情報        |
| 2   | users                     | 基盤    | テナント内のユーザーアカウント     |
| 3   | customers                 | 顧客管理  | 取引先（顧客・仕入先）マスタ      |
| 4   | customer_contacts         | 顧客管理  | 取引先の担当者連絡先          |
| 5   | products                  | 品目管理  | 商品・サービスマスタ          |
| 6   | projects                  | 案件管理  | 商談・プロジェクト           |
| 7   | documents                 | 帳票管理  | 見積書・請求書・発注書・納品書・領収書 |
| 8   | document_items            | 帳票管理  | 帳票の明細行              |
| 9   | document_versions         | 帳票管理  | 帳票の変更履歴（スナップショット）   |
| 10  | recurring_rules           | 帳票管理  | 定期請求ルール             |
| 11  | payment_records           | 入金管理  | 入金記録（手動消込・AI消込）     |
| 12  | bank_statements           | 入金管理  | 銀行明細（CSVインポート）      |
| 13  | dunning_rules             | 督促管理  | 督促ルール定義             |
| 14  | dunning_logs              | 督促管理  | 督促実行履歴              |
| 15  | credit_score_histories    | 与信管理  | 顧客の与信スコア履歴          |
| 16  | import_jobs               | データ移行 | CSVインポートジョブ         |
| 17  | import_column_definitions | データ移行 | カラムマッピング定義辞書        |
| 18  | industry_templates        | マスタ   | 業種別テンプレート           |
| 19  | notifications             | 通知    | ユーザーへの通知            |
| 20  | audit_logs                | 監査    | 全操作の監査ログ            |


---

## ER図（テキスト）

```
tenants
  |-- users
  |-- customers
  |     |-- customer_contacts
  |     |-- credit_score_histories
  |     |-- projects
  |     |     |-- documents
  |     |-- documents
  |           |-- document_items ──> products
  |           |-- document_versions
  |           |-- payment_records ──> bank_statements
  |           |-- dunning_logs ──> dunning_rules
  |-- products
  |-- dunning_rules
  |-- recurring_rules ──> customers, projects
  |-- bank_statements
  |-- import_jobs
  |-- notifications ──> users
  |-- audit_logs ──> users

industry_templates（テナント非依存マスタ）
import_column_definitions（テナント非依存マスタ）
```

---

## テーブル詳細

### 1. tenants（テナント）

**機能**: 契約企業の情報を管理する。全データの起点。


| カラム                           | 型          | 説明                                        |
| ----------------------------- | ---------- | ----------------------------------------- |
| uuid                          | uuid       | 外部公開用ID                                   |
| name                          | string     | 会社名                                       |
| name_kana                     | string     | 会社名カナ                                     |
| postal_code〜address_line2     | string     | 住所                                        |
| phone, fax, email, website    | string     | 連絡先                                       |
| invoice_registration_number   | string     | インボイス登録番号（T+13桁）                          |
| invoice_number_verified       | boolean    | NTA APIで番号検証済みか                           |
| logo_url, seal_url            | string     | ロゴ・印影の画像URL                               |
| bank_name〜bank_account_holder | string/int | 振込先口座情報                                   |
| industry_type                 | string     | 業種コード（general等）                           |
| fiscal_year_start_month       | integer    | 会計年度開始月（デフォルト4月）                          |
| plan                          | string     | 契約プラン（free/starter/standard/professional） |
| plan_started_at               | datetime   | プラン開始日                                    |
| stripe_customer_id            | string     | Stripe顧客ID                                |
| stripe_subscription_id        | string     | StripeサブスクリプションID                         |
| document_sequence_format      | string     | 帳票採番フォーマット                                |
| default_payment_terms_days    | integer    | デフォルト支払期限（日）                              |
| default_tax_rate              | decimal    | デフォルト消費税率                                 |
| dunning_enabled               | boolean    | 自動督促の有効/無効                                |
| import_enabled                | boolean    | データ移行機能の有効/無効                             |
| timezone                      | string     | タイムゾーン                                    |
| deleted_at                    | datetime   | 論理削除日時                                    |


**リレーション**: 全テーブルの親

---

### 2. users（ユーザー）

**機能**: テナント内のユーザーアカウント。認証・認可の主体。


| カラム                    | 型        | 説明                                       |
| ---------------------- | -------- | ---------------------------------------- |
| uuid                   | uuid     | 外部公開用ID                                  |
| tenant_id              | bigint   | 所属テナント（FK）                               |
| email                  | string   | メールアドレス（テナント内ユニーク）                       |
| password_digest        | string   | bcryptハッシュ化パスワード                         |
| name                   | string   | ユーザー名                                    |
| role                   | string   | ロール（owner/admin/accountant/sales/member） |
| avatar_url             | string   | アバター画像URL                                |
| last_sign_in_at        | datetime | 最終ログイン日時                                 |
| sign_in_count          | integer  | ログイン回数                                   |
| invitation_token       | string   | 招待トークン                                   |
| invitation_sent_at     | datetime | 招待メール送信日時                                |
| invitation_accepted_at | datetime | 招待承諾日時                                   |
| password_reset_token   | string   | パスワードリセットトークン                            |
| two_factor_enabled     | boolean  | 2要素認証の有効/無効                              |
| otp_secret             | string   | OTPシークレット                                |
| jti                    | string   | JWT無効化用ID（ユニーク）                          |
| deleted_at             | datetime | 論理削除日時                                   |


**リレーション**: `tenants` に所属

---

### 3. customers（顧客）

**機能**: 取引先（顧客・仕入先）のマスタ情報。帳票の宛先・与信管理の対象。


| カラム                             | 型          | 説明                                |
| ------------------------------- | ---------- | --------------------------------- |
| uuid                            | uuid       | 外部公開用ID                           |
| tenant_id                       | bigint     | 所属テナント（FK）                        |
| customer_type                   | string     | 種別（client=顧客 / vendor=仕入先 / both） |
| company_name                    | string     | 会社名                               |
| company_name_kana               | string     | 会社名カナ                             |
| department, title, contact_name | string     | 担当者情報                             |
| email, phone, fax               | string     | 連絡先                               |
| postal_code〜address_line2       | string     | 住所                                |
| invoice_registration_number     | string     | インボイス登録番号                         |
| payment_terms_days              | integer    | 支払サイト（日）                          |
| default_tax_rate                | decimal    | デフォルト税率                           |
| bank_name〜bank_account_holder   | string/int | 振込先口座                             |
| tags                            | jsonb      | タグ（配列）                            |
| memo                            | text       | メモ                                |
| credit_score                    | integer    | 現在の与信スコア（0-100）                   |
| avg_payment_days                | decimal    | 平均入金日数                            |
| late_payment_rate               | decimal    | 遅延率                               |
| total_outstanding               | bigint     | 未回収残高合計                           |
| imported_from, external_id      | string     | データ移行元の識別情報                       |
| deleted_at                      | datetime   | 論理削除日時                            |


**リレーション**: `tenants` に所属 / `customer_contacts`, `projects`, `documents`, `credit_score_histories` の親

---

### 4. customer_contacts（顧客担当者）

**機能**: 顧客企業ごとの担当者連絡先。請求先・督促先の指定に使用。


| カラム                | 型       | 説明       |
| ------------------ | ------- | -------- |
| customer_id        | bigint  | 所属顧客（FK） |
| name               | string  | 担当者名     |
| email              | string  | メールアドレス  |
| phone              | string  | 電話番号     |
| department         | string  | 部署       |
| title              | string  | 役職       |
| is_primary         | boolean | 主担当か     |
| is_billing_contact | boolean | 請求先担当か   |
| memo               | text    | メモ       |


**リレーション**: `customers` に所属

---

### 5. products（品目）

**機能**: 商品・サービスのマスタ。帳票の明細行作成時に参照。


| カラム           | 型       | 説明                            |
| ------------- | ------- | ----------------------------- |
| tenant_id     | bigint  | 所属テナント（FK）                    |
| code          | string  | 品目コード                         |
| name          | string  | 品目名                           |
| description   | text    | 説明                            |
| unit          | string  | 単位（個、時間、式 等）                  |
| unit_price    | bigint  | 単価（円）                         |
| tax_rate      | decimal | 税率                            |
| tax_rate_type | string  | 税率区分（standard/reduced/exempt） |
| category      | string  | カテゴリ                          |
| sort_order    | integer | 表示順                           |
| is_active     | boolean | 有効/無効                         |


**リレーション**: `tenants` に所属 / `document_items` から参照される

---

### 6. projects（案件）

**機能**: 商談・プロジェクトの管理。帳票を案件に紐付けて進捗・売上を追跡。


| カラム                        | 型        | 説明                                                                       |
| -------------------------- | -------- | ------------------------------------------------------------------------ |
| uuid                       | uuid     | 外部公開用ID                                                                  |
| tenant_id                  | bigint   | 所属テナント（FK）                                                               |
| customer_id                | bigint   | 顧客（FK）                                                                   |
| assigned_user_id           | bigint   | 担当ユーザー（FK）                                                               |
| project_number             | string   | 案件番号（テナント内ユニーク）                                                          |
| name                       | string   | 案件名                                                                      |
| status                     | string   | ステータス（negotiation/ordered/in_progress/delivered/invoiced/completed/lost） |
| probability                | integer  | 受注確度（%）                                                                  |
| amount                     | bigint   | 見込金額                                                                     |
| cost                       | bigint   | 見込原価                                                                     |
| start_date, end_date       | date     | 期間                                                                       |
| description                | text     | 説明                                                                       |
| tags                       | jsonb    | タグ                                                                       |
| custom_fields              | jsonb    | カスタムフィールド                                                                |
| imported_from, external_id | string   | データ移行元識別情報                                                               |
| deleted_at                 | datetime | 論理削除日時                                                                   |


**リレーション**: `tenants`, `customers`, `users` に所属 / `documents` の親

---

### 7. documents（帳票）

**機能**: 見積書・請求書・発注書・納品書・領収書。システムの中核テーブル。


| カラム                        | 型        | 説明                                                          |
| -------------------------- | -------- | ----------------------------------------------------------- |
| uuid                       | uuid     | 外部公開用ID                                                     |
| tenant_id                  | bigint   | 所属テナント（FK）                                                  |
| project_id                 | bigint   | 案件（FK、任意）                                                   |
| customer_id                | bigint   | 顧客（FK）                                                      |
| created_by_user_id         | bigint   | 作成者（FK）                                                     |
| document_type              | string   | 帳票種別（estimate/invoice/purchase_order/delivery_note/receipt） |
| document_number            | string   | 帳票番号（テナント+種別内ユニーク）                                          |
| status                     | string   | ステータス（draft/pending/approved/rejected/sent/locked）          |
| version                    | integer  | バージョン番号                                                     |
| parent_document_id         | bigint   | 変換元帳票（FK、自己参照）                                              |
| title                      | string   | 件名                                                          |
| issue_date                 | date     | 発行日                                                         |
| due_date                   | date     | 支払期限                                                        |
| valid_until                | date     | 見積有効期限                                                      |
| subtotal                   | bigint   | 小計（税抜）                                                      |
| tax_amount                 | bigint   | 消費税合計                                                       |
| total_amount               | bigint   | 合計（税込）                                                      |
| tax_summary                | jsonb    | 税率別内訳                                                       |
| notes                      | text     | 備考（帳票に印字）                                                   |
| internal_memo              | text     | 社内メモ                                                        |
| sender_snapshot            | jsonb    | 送付時の自社情報スナップショット                                            |
| recipient_snapshot         | jsonb    | 送付時の顧客情報スナップショット                                            |
| pdf_url                    | string   | 生成済みPDFのURL                                                 |
| pdf_generated_at           | datetime | PDF生成日時                                                     |
| sent_at                    | datetime | 送信日時                                                        |
| sent_method                | string   | 送信方法（email等）                                                |
| locked_at                  | datetime | ロック日時                                                       |
| payment_status             | string   | 入金ステータス（unpaid/partial/paid/overdue）                        |
| paid_amount                | bigint   | 入金済み金額                                                      |
| remaining_amount           | bigint   | 未入金残高                                                       |
| last_dunning_at            | datetime | 最終督促日時                                                      |
| dunning_count              | integer  | 督促回数                                                        |
| is_recurring               | boolean  | 定期請求か                                                       |
| recurring_rule_id          | bigint   | 定期請求ルール（FK）                                                 |
| imported_from, external_id | string   | データ移行元識別情報                                                  |
| deleted_at                 | datetime | 論理削除日時                                                      |


**リレーション**: `tenants`, `customers`, `projects`, `users` に所属 / `document_items`, `document_versions`, `payment_records`, `dunning_logs` の親 / `parent_document_id` で帳票変換チェーンを形成

**帳票変換チェーン例**:

```
見積書 → 発注書 → 納品書 → 請求書 → 領収書
         └──────────────→ 請求書
```

---

### 8. document_items（帳票明細）

**機能**: 帳票の明細行。商品名・数量・単価・税率・金額を保持。


| カラム           | 型       | 説明                        |
| ------------- | ------- | ------------------------- |
| document_id   | bigint  | 帳票（FK）                    |
| product_id    | bigint  | 品目マスタ（FK、任意）              |
| sort_order    | integer | 表示順                       |
| item_type     | string  | 行種別（normal/discount/note） |
| name          | string  | 品名                        |
| description   | text    | 説明                        |
| quantity      | decimal | 数量                        |
| unit          | string  | 単位                        |
| unit_price    | bigint  | 単価                        |
| amount        | bigint  | 金額（数量 x 単価）               |
| tax_rate      | decimal | 税率                        |
| tax_rate_type | string  | 税率区分                      |
| tax_amount    | bigint  | 税額                        |


**リレーション**: `documents` に所属 / `products` を参照（任意）

---

### 9. document_versions（帳票バージョン）

**機能**: 帳票の変更履歴。編集のたびにスナップショットを保存。


| カラム                | 型       | 説明              |
| ------------------ | ------- | --------------- |
| document_id        | bigint  | 帳票（FK）          |
| version            | integer | バージョン番号         |
| snapshot           | jsonb   | 帳票データの全スナップショット |
| pdf_url            | string  | その時点のPDF URL    |
| changed_by_user_id | bigint  | 変更者（FK）         |
| change_reason      | text    | 変更理由            |


**リレーション**: `documents`, `users` に所属

---

### 10. recurring_rules（定期請求ルール）

**機能**: 毎月・毎年などの定期請求を自動生成するためのルール定義。


| カラム                  | 型       | 説明                 |
| -------------------- | ------- | ------------------ |
| tenant_id            | bigint  | 所属テナント（FK）         |
| customer_id          | bigint  | 対象顧客（FK）           |
| project_id           | bigint  | 対象案件（FK、任意）        |
| name                 | string  | ルール名               |
| frequency            | string  | 頻度（monthly/yearly） |
| generation_day       | integer | 生成日                |
| issue_day            | integer | 発行日                |
| next_generation_date | date    | 次回生成予定日            |
| template_items       | jsonb   | 明細テンプレート           |
| auto_send            | boolean | 自動送信するか            |
| is_active            | boolean | 有効/無効              |
| start_date, end_date | date    | 有効期間               |


**リレーション**: `tenants`, `customers`, `projects` に所属 / `documents` から参照される

---

### 11. payment_records（入金記録）

**機能**: 請求書に対する入金の記録。手動入力またはAI消込で作成。


| カラム                 | 型       | 説明                                    |
| ------------------- | ------- | ------------------------------------- |
| uuid                | uuid    | 外部公開用ID                               |
| tenant_id           | bigint  | 所属テナント（FK）                            |
| document_id         | bigint  | 対象請求書（FK）                             |
| bank_statement_id   | bigint  | 紐付いた銀行明細（FK、任意）                       |
| amount              | bigint  | 入金額                                   |
| payment_date        | date    | 入金日                                   |
| payment_method      | string  | 支払方法（bank_transfer/cash/credit_card等） |
| matched_by          | string  | 消込方法（manual/ai/rule）                  |
| match_confidence    | decimal | AI消込の信頼度（0-1）                         |
| memo                | text    | メモ                                    |
| recorded_by_user_id | bigint  | 記録者（FK）                               |


**リレーション**: `tenants`, `documents`, `users` に所属 / `bank_statements` を参照（任意）

**入金時の自動処理**: payment_records が作成/削除されると、documents の `paid_amount`, `remaining_amount`, `payment_status` が自動更新される

---

### 12. bank_statements（銀行明細）

**機能**: 銀行口座のCSV明細をインポートして保持。AI消込のソースデータ。


| カラム                      | 型       | 説明            |
| ------------------------ | ------- | ------------- |
| tenant_id                | bigint  | 所属テナント（FK）    |
| transaction_date         | date    | 取引日           |
| value_date               | date    | 起算日           |
| description              | string  | 摘要            |
| payer_name               | string  | 振込人名義         |
| amount                   | bigint  | 金額            |
| balance                  | bigint  | 残高            |
| bank_name                | string  | 銀行名           |
| account_number           | string  | 口座番号          |
| is_matched               | boolean | 消込済みか         |
| matched_document_id      | bigint  | 消込先請求書（FK、任意） |
| ai_suggested_document_id | bigint  | AI提案の請求書      |
| ai_match_confidence      | decimal | AI提案の信頼度      |
| ai_match_reason          | text    | AI提案の理由       |
| import_batch_id          | string  | インポートバッチID    |
| raw_data                 | jsonb   | CSVの生データ      |


**リレーション**: `tenants` に所属 / `documents` を参照 / `payment_records` から参照される

**AI消込フロー**:

```
CSVインポート → bank_statements作成 → AI5段階マッチング → 提案表示 → ユーザー承認 → payment_records作成
```

---

### 13. dunning_rules（督促ルール）

**機能**: 支払い遅延時の督促ルールを定義。テナントごとに複数設定可能。


| カラム                    | 型       | 説明                                          |
| ---------------------- | ------- | ------------------------------------------- |
| tenant_id              | bigint  | 所属テナント（FK）                                  |
| name                   | string  | ルール名（例: 初回督促、最終警告）                          |
| trigger_days_after_due | integer | 支払期限からの経過日数で発動                              |
| action_type            | string  | アクション種別（email/notification）                 |
| email_template_subject | string  | メール件名テンプレート                                 |
| email_template_body    | text    | メール本文テンプレート                                 |
| send_to                | string  | 送信先（billing_contact/primary_contact/custom） |
| custom_email           | string  | カスタム送信先メールアドレス                              |
| is_active              | boolean | 有効/無効                                       |
| sort_order             | integer | 実行順                                         |
| max_dunning_count      | integer | 最大督促回数                                      |
| interval_days          | integer | 督促間隔（日）                                     |
| escalation_rule_id     | bigint  | エスカレーション先ルール（FK、自己参照）                       |


**リレーション**: `tenants` に所属 / `dunning_logs` から参照される

---

### 14. dunning_logs（督促履歴）

**機能**: 実行された督促の記録。いつ・誰に・何の請求書について督促したかを保存。


| カラム              | 型       | 説明                   |
| ---------------- | ------- | -------------------- |
| tenant_id        | bigint  | 所属テナント（FK）           |
| document_id      | bigint  | 対象請求書（FK）            |
| dunning_rule_id  | bigint  | 適用ルール（FK）            |
| customer_id      | bigint  | 対象顧客（FK）             |
| action_type      | string  | アクション種別              |
| sent_to_email    | string  | 送信先メールアドレス           |
| email_subject    | string  | 送信メール件名              |
| email_body       | text    | 送信メール本文              |
| status           | string  | 送信ステータス（sent/failed） |
| overdue_days     | integer | 遅延日数                 |
| remaining_amount | bigint  | 督促時点の未回収額            |


**リレーション**: `tenants`, `documents`, `dunning_rules`, `customers` に所属

---

### 15. credit_score_histories（与信スコア履歴）

**機能**: 顧客の与信スコアの推移を記録。定期バッチで計算・保存。


| カラム           | 型        | 説明              |
| ------------- | -------- | --------------- |
| tenant_id     | bigint   | 所属テナント（FK）      |
| customer_id   | bigint   | 対象顧客（FK）        |
| score         | integer  | スコア（0-100、基準50） |
| factors       | jsonb    | スコア算出の加減点要因     |
| calculated_at | datetime | 算出日時            |


**リレーション**: `tenants`, `customers` に所属

**スコア算出ロジック**: 基準50点から、入金遅延・遅延率・取引金額・取引頻度等で加減点し0-100でクランプ

---

### 16. import_jobs（インポートジョブ）

**機能**: データ移行ウィザードのジョブ管理。アップロードからインポート完了までの状態を追跡。


| カラム                   | 型        | 説明                                                        |
| --------------------- | -------- | --------------------------------------------------------- |
| uuid                  | uuid     | 外部公開用ID                                                   |
| tenant_id             | bigint   | 所属テナント（FK）                                                |
| user_id               | bigint   | 実行ユーザー（FK）                                                |
| source_type           | string   | ソース種別（board/excel/csv）                                    |
| status                | string   | ステータス（pending/mapping/preview/executing/completed/failed） |
| file_url              | string   | アップロードファイルURL                                             |
| file_name             | string   | ファイル名                                                     |
| file_size             | bigint   | ファイルサイズ                                                   |
| parsed_data           | jsonb    | パース済みデータ（ヘッダー+行）                                          |
| column_mapping        | jsonb    | カラムマッピング定義                                                |
| preview_data          | jsonb    | プレビュー用データ                                                 |
| import_stats          | jsonb    | 結果統計（成功/スキップ/エラー件数）                                       |
| error_details         | jsonb    | エラー詳細（行番号+メッセージ）                                          |
| ai_mapping_confidence | decimal  | AIマッピングの全体信頼度                                             |
| started_at            | datetime | 実行開始日時                                                    |
| completed_at          | datetime | 完了日時                                                      |


**リレーション**: `tenants`, `users` に所属

---

### 17. import_column_definitions（カラムマッピング辞書）

**機能**: データ移行時のCSVカラム名とウケトリのカラムの対応辞書。テナント非依存のマスタ。


| カラム                | 型       | 説明                     |
| ------------------ | ------- | ---------------------- |
| source_type        | string  | ソース種別（board/excel/csv） |
| source_column_name | string  | CSV側のカラム名              |
| target_table       | string  | 対応するウケトリのテーブル名         |
| target_column      | string  | 対応するウケトリのカラム名          |
| transform_rule     | string  | 変換ルール                  |
| is_required        | boolean | 必須カラムか                 |


**リレーション**: なし（グローバルマスタ）

---

### 18. industry_templates（業種テンプレート）

**機能**: 業種別の用語・デフォルト品目・税設定のテンプレート。テナント非依存のマスタ。


| カラム                | 型       | 説明              |
| ------------------ | ------- | --------------- |
| code               | string  | テンプレートコード（ユニーク） |
| name               | string  | 業種名             |
| labels             | jsonb   | 業種固有の用語マッピング    |
| default_products   | jsonb   | デフォルト品目リスト      |
| default_statuses   | jsonb   | デフォルトステータス      |
| document_templates | jsonb   | 帳票テンプレート        |
| tax_settings       | jsonb   | 税設定             |
| sort_order         | integer | 表示順             |
| is_active          | boolean | 有効/無効           |


**リレーション**: なし（グローバルマスタ）

---

### 19. notifications（通知）

**機能**: ユーザーへのアプリ内通知。入金確認・督促送信・インポート完了等を通知。


| カラム               | 型        | 説明          |
| ----------------- | -------- | ----------- |
| tenant_id         | bigint   | 所属テナント（FK）  |
| user_id           | bigint   | 通知先ユーザー（FK） |
| notification_type | string   | 通知種別        |
| title             | string   | 通知タイトル      |
| body              | text     | 通知本文        |
| data              | jsonb    | 付加データ       |
| is_read           | boolean  | 既読か         |
| read_at           | datetime | 既読日時        |


**リレーション**: `tenants`, `users` に所属

---

### 20. audit_logs（監査ログ）

**機能**: 全ての作成・更新・削除操作の監査証跡。コンプライアンス・障害調査用。


| カラム           | 型      | 説明                                                                      |
| ------------- | ------ | ----------------------------------------------------------------------- |
| tenant_id     | bigint | 所属テナント（FK）                                                              |
| user_id       | bigint | 操作ユーザー（FK、任意）                                                           |
| action        | string | アクション（create/update/delete/send/lock/import/export/login/match/execute） |
| resource_type | string | リソース種別（document/customer/project等）                                      |
| resource_id   | bigint | リソースID                                                                  |
| changes_data  | jsonb  | 変更内容                                                                    |
| ip_address    | inet   | IPアドレス                                                                  |
| user_agent    | string | ユーザーエージェント                                                              |


**リレーション**: `tenants`, `users` に所属

---

## システムテーブル（Rails/SolidQueue）

### ActiveStorage（3テーブル）

ファイルアップロード（ロゴ・印影・PDF等）の管理用。Rails標準機能。


| テーブル                           | 用途               |
| ------------------------------ | ---------------- |
| active_storage_blobs           | アップロードファイルのメタデータ |
| active_storage_attachments     | ファイルとレコードの紐付け    |
| active_storage_variant_records | 画像バリアント（サムネイル等）  |


### SolidQueue（11テーブル）

バックグラウンドジョブ（PDF生成・督促実行・インポート等）の管理用。PostgreSQL-backed。


| テーブル                             | 用途          |
| -------------------------------- | ----------- |
| solid_queue_jobs                 | ジョブ本体       |
| solid_queue_ready_executions     | 実行可能なジョブ    |
| solid_queue_scheduled_executions | スケジュール済みジョブ |
| solid_queue_claimed_executions   | 実行中のジョブ     |
| solid_queue_blocked_executions   | ブロック中のジョブ   |
| solid_queue_failed_executions    | 失敗したジョブ     |
| solid_queue_recurring_executions | 定期実行の履歴     |
| solid_queue_recurring_tasks      | 定期タスク定義     |
| solid_queue_processes            | ワーカープロセス    |
| solid_queue_pauses               | キュー一時停止     |
| solid_queue_semaphores           | 同時実行制御      |


---

## 機能別データフロー

### 帳票ライフサイクル

```
products（品目選択）
    ↓
documents（帳票作成: draft）
    + document_items（明細行追加）
    ↓ approve
documents（status: approved）
    ↓ PDF生成
documents（pdf_url設定）+ ActiveStorage
    ↓ メール送信
documents（status: sent, sent_at設定）
    ↓ ロック
documents（status: locked, locked_at設定）
    + document_versions（スナップショット保存）
```

### 入金消込フロー

```
bank_statements（CSVインポート）
    ↓ AI5段階マッチング
bank_statements（ai_suggested_document_id設定）
    ↓ ユーザー承認
payment_records（作成）
    ↓ コールバック
documents（paid_amount/remaining_amount/payment_status更新）
    ↓ 全額入金完了
documents（payment_status: paid）
```

### 督促フロー

```
documents（payment_status: overdue）
    ↓ 日次バッチ
dunning_rules（ルール照合: trigger_days_after_due）
    ↓ 条件一致
dunning_logs（督促記録作成）+ メール送信
    ↓
documents（last_dunning_at/dunning_count更新）
    ↓ 定期バッチ
credit_score_histories（与信スコア再計算）
    → customers（credit_score更新）
```

### 帳票変換フロー

```
estimate（見積書）
    ├→ invoice（請求書）  parent_document_id = estimate.id
    └→ purchase_order（発注書）  parent_document_id = estimate.id

purchase_order（発注書）
    ├→ delivery_note（納品書）  parent_document_id = PO.id
    └→ invoice（請求書）  parent_document_id = PO.id

invoice（請求書）
    └→ receipt（領収書）  parent_document_id = invoice.id
```

