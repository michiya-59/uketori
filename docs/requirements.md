# ウケトリ（UKETORI）完全要件定義書 v1.2

> **最終更新日:** 2026-04-06
> **ドキュメントオーナー:** スズキ
> **ステータス:** Draft
> **v1.2 変更点:** インフラ構成をAWS Lightsail + Resendに変更。バックアップ・監視・サーバーハードニング手順を追加
> **v1.1 変更点:** インフラ構成を極限コスト最適化（月額¥500〜3,000）に刷新

---

# 第1部：プロジェクト概要

## 1.1 プロダクトビジョン

**プロダクト名:** ウケトリ（UKETORI）
**タグライン:** 見積から入金まで、ぜんぶウケトリ。
**ポジショニング:** 中小企業・フリーランス向け AI搭載 受発注・請求・入金回収管理SaaS

### コアコンセプト
見積 → 受発注 → 納品 → 請求 → **入金回収** を一気通貫で管理するクラウドSaaS。
2つの差別化軸で競合と明確に差別化する。

| 差別化軸 | 概要 |
|---------|------|
| **①入金回収特化** | 請求書を「送って終わり」にしない。AI入金消込・自動督促・回収率ダッシュボード・与信スコアリングにより「確実に回収する」ことにフォーカス |
| **②移行爆速** | 他ツール（board, freee, Misoca, MakeLeaps, Excel）からのデータ移行を最短5分で完了。インポートウィザード＋AI自動マッピングにより乗り換えの心理的障壁をゼロにする |

### ターゲットユーザー
- 従業員1〜50名の中小企業・個人事業主
- 業種不問（全業種対応）
- 現在Excel・紙・スプレッドシート・他SaaSで受発注・請求管理を行っている事業者
- **特に「入金回収に課題がある」事業者を最重要ターゲットとする**

## 1.2 用語定義

| 用語 | 定義 |
|------|------|
| テナント | 1つの契約企業単位。マルチテナントアーキテクチャにおける分離単位 |
| オーナー | テナント作成者。全権限を持つ |
| メンバー | テナントに招待されたユーザー |
| 案件 | 1つの取引・プロジェクト単位。見積〜入金までのライフサイクルを持つ |
| 帳票 | 見積書・発注書・注文請書・納品書・請求書・領収書の総称 |
| 消込 | 請求書と入金明細を紐づけて入金確認済とする処理 |
| 督促 | 支払期日超過の取引先に支払いを促す通知 |
| 与信スコア | 取引先の支払い信頼性を0-100で数値化したもの |
| インポートジョブ | 他ツールからのデータ移行処理単位 |

## 1.3 システム全体像

### インフラ基本方針
- **極限コスト運用:** 初期フェーズ（0〜100ユーザー）は月額¥0〜1,500を目標
- **段階的スケールアップ:** ユーザー増加に応じてインフラを拡張
- **AWS活用:** AWS Lightsail → EC2/ECS への自然なスケールアップパスを確保
- **ポータビリティ:** PostgreSQL + S3互換APIを採用
- **Redis撤廃:** SolidQueue / SolidCacheによりRedis依存を完全排除

```
┌─────────────────────────────────────────────────────────┐
│                    ユーザー（ブラウザ）                    │
└──────────────────────┬──────────────────────────────────┘
                       │ HTTPS
┌──────────────────────▼──────────────────────────────────┐
│              Cloudflare（DNS + CDN + SSL）¥0             │
└──────────┬───────────────────────┬──────────────────────┘
           │                       │
┌──────────▼──────────┐ ┌─────────▼──────────────────────┐
│ Vercel               │ │ AWS Lightsail                    │
│ Next.js フロントエンド│ │ Ruby on Rails API サーバー       │
│ - SSR/SSG（LP・ヘルプ）│ │ - APIモード（Rails 7.x）         │
│ - SPA（アプリ本体）   │ │ - JWT認証（devise-jwt）          │
│ - Tailwind CSS       │ │ - Pundit（認可）                 │
│ - shadcn/ui          │ │ - ActiveStorage（→ R2）          │
│ Hobby→Pro ¥0〜$20   │ │ - SolidQueue（非同期ジョブ）      │
└─────────────────────┘ │ - SolidCache（キャッシュ）        │
                        │ - Nginx（リバースプロキシ）        │
                        │ Micro $7/月                       │
                        └────┬──────────┬─────────────────┘
                             │          │
              ┌──────────────┼──────────┼──────────────┐
              │              │          │              │
       ┌──────▼──┐   ┌──────▼──┐ ┌────▼─────┐ ┌─────▼───────┐
       │Supabase │   │Cloudflare│ │Cloudflare│ │外部API      │
       │PostgreSQL│   │R2       │ │(CDN/DNS) │ │- Claude API │
       │Managed DB│   │(PDF/    │ │¥0       │ │- 国税庁API  │
       │¥0       │   │ 画像)   │ │          │ │- Resend     │
       │         │   │¥0       │ │          │ │- Stripe     │
       │+Solid   │   │S3互換API│ │          │ └─────────────┘
       │ Queue   │   └─────────┘ └──────────┘
       │ Cache   │
       │ テーブル │
       └─────────┘
```

### インフラ費用内訳（Phase 1: 0〜100ユーザー）

| サービス | 用途 | 月額 | 無料枠 |
|---------|------|------|--------|
| Vercel (Hobby→Pro) | Next.jsホスティング | ¥0〜$20 | Hobby無料。有償ユーザー獲得後Pro化 |
| AWS Lightsail (Micro) | Rails API + Nginx + Docker | $7 | Micro-1GB プラン |
| Supabase PostgreSQL (Free) | データベース | ¥0 | 500MB / 東京リージョン利用可 |
| Cloudflare R2 (Free) | PDF・画像保存 | ¥0 | 10GB / S3互換 / エグレス無料 |
| Cloudflare (Free) | DNS + SSL | ¥0 | |
| Resend (Free) | メール送信 | ¥0 | 月3,000通 |
| Sentry (Free) | エラー監視 | ¥0 | 月5,000イベント |
| BetterStack (Free) | 外形監視 | ¥0 | 5モニター |
| GitHub Actions | CI/CD | ¥0 | 月2,000分 |
| **合計** | | **約¥1,050 + Claude API従量課金** | |

### スケールアップ計画

| ユーザー数 | 構成変更 | 月額目安 |
|-----------|---------|---------|
| 0〜50 | Lightsail Micro-1GB ($7) + Supabase Free + Vercel Hobby | ¥1,050 + Claude API |
| 50〜200 | Lightsail Small-2GB ($12) + Vercel Pro ($20) | ¥5,000〜7,000 |
| 200〜500 | Lightsail Medium-4GB ($24) + Supabase Pro ($25) + SolidQueue別プロセス化 | ¥10,000〜15,000 |
| 500〜1,000 | EC2 + RDS + ロードバランサー | ¥20,000〜30,000 |
| 1,000+ | ECS (Fargate) + Aurora でフルスケール | ¥50,000〜 |

---

# 第2部：データベース設計

## 2.1 ER図概要

```
tenants ─┬─< users
         ├─< customers ─┬─< customer_contacts
         │              └─< credit_scores (★入金回収特化)
         ├─< projects ──┬─< documents (見積/発注/納品/請求/領収)
         │              └─< project_notes
         ├─< products (品目マスタ)
         ├─< payment_records (入金記録)
         ├─< bank_statements (銀行明細) (★入金回収特化)
         ├─< dunning_rules (督促ルール) (★入金回収特化)
         ├─< dunning_logs (督促履歴) (★入金回収特化)
         ├─< import_jobs (★移行爆速)
         ├─< industry_templates
         └─< notification_settings

※ SolidQueue / SolidCache 用の内部テーブルも同一DBに作成
  - solid_queue_jobs, solid_queue_scheduled_executions, etc.
  - solid_cache_entries
```

## 2.2 テーブル定義（全テーブル）

### 2.2.1 tenants（テナント）

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|----------|------|
| id | bigint | NO | auto | PK |
| uuid | uuid | NO | gen_random_uuid() | 外部公開用ID |
| name | varchar(255) | NO | | 会社名 / 屋号 |
| name_kana | varchar(255) | YES | | 会社名カナ |
| postal_code | varchar(8) | YES | | 郵便番号（ハイフンなし） |
| prefecture | varchar(10) | YES | | 都道府県 |
| city | varchar(100) | YES | | 市区町村 |
| address_line1 | varchar(255) | YES | | 番地 |
| address_line2 | varchar(255) | YES | | 建物名 |
| phone | varchar(20) | YES | | 電話番号 |
| fax | varchar(20) | YES | | FAX番号 |
| email | varchar(255) | YES | | 代表メール |
| website | varchar(500) | YES | | Webサイト |
| invoice_registration_number | varchar(14) | YES | | 適格請求書発行事業者登録番号（T+13桁） |
| invoice_number_verified | boolean | NO | false | 国税庁APIで検証済みか |
| invoice_number_verified_at | timestamp | YES | | 検証日時 |
| logo_url | varchar(500) | YES | | ロゴ画像URL（R2） |
| seal_url | varchar(500) | YES | | 印影画像URL（R2） |
| bank_name | varchar(100) | YES | | 振込先銀行名 |
| bank_branch_name | varchar(100) | YES | | 支店名 |
| bank_account_type | smallint | YES | | 0:普通 1:当座 |
| bank_account_number | varchar(10) | YES | | 口座番号 |
| bank_account_holder | varchar(100) | YES | | 口座名義 |
| industry_type | varchar(50) | NO | 'general' | 業種タイプ（industry_templates.code） |
| fiscal_year_start_month | smallint | NO | 4 | 会計年度開始月(1-12) |
| plan | varchar(30) | NO | 'free' | free/starter/standard/professional |
| plan_started_at | timestamp | YES | | プラン開始日 |
| stripe_customer_id | varchar(100) | YES | | Stripe顧客ID |
| stripe_subscription_id | varchar(100) | YES | | StripeサブスクリプションID |
| document_sequence_format | varchar(100) | NO | '{prefix}-{YYYY}{MM}-{SEQ}' | 帳票採番フォーマット |
| default_payment_terms_days | integer | NO | 30 | デフォルト支払期日（日数） |
| default_tax_rate | decimal(5,2) | NO | 10.00 | デフォルト税率 |
| dunning_enabled | boolean | NO | false | 自動督促を有効にするか(★入金回収) |
| timezone | varchar(50) | NO | 'Asia/Tokyo' | タイムゾーン |
| created_at | timestamp | NO | now() | |
| updated_at | timestamp | NO | now() | |
| deleted_at | timestamp | YES | | 論理削除 |

**インデックス:**
- `idx_tenants_uuid` UNIQUE (uuid)
- `idx_tenants_stripe_customer_id` (stripe_customer_id)
- `idx_tenants_deleted_at` (deleted_at)

---

### 2.2.2 users（ユーザー）

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|----------|------|
| id | bigint | NO | auto | PK |
| uuid | uuid | NO | gen_random_uuid() | |
| tenant_id | bigint | NO | | FK → tenants.id |
| email | varchar(255) | NO | | ログインメール（テナント内UNIQUE） |
| encrypted_password | varchar(255) | NO | | bcryptハッシュ |
| name | varchar(100) | NO | | 表示名 |
| role | varchar(20) | NO | 'member' | owner / admin / accountant / sales / member |
| avatar_url | varchar(500) | YES | | |
| last_sign_in_at | timestamp | YES | | |
| sign_in_count | integer | NO | 0 | |
| invitation_token | varchar(100) | YES | | 招待トークン |
| invitation_sent_at | timestamp | YES | | |
| invitation_accepted_at | timestamp | YES | | |
| password_reset_token | varchar(100) | YES | | |
| password_reset_sent_at | timestamp | YES | | |
| two_factor_enabled | boolean | NO | false | |
| otp_secret | varchar(100) | YES | | TOTP秘密鍵（暗号化） |
| created_at | timestamp | NO | now() | |
| updated_at | timestamp | NO | now() | |
| deleted_at | timestamp | YES | | |

**インデックス:**
- `idx_users_uuid` UNIQUE (uuid)
- `idx_users_tenant_email` UNIQUE (tenant_id, email) WHERE deleted_at IS NULL
- `idx_users_invitation_token` UNIQUE (invitation_token)

**ロール定義:**

| ロール | 説明 | 権限概要 |
|--------|------|---------|
| owner | テナントオーナー | 全権限。プラン変更・テナント削除が可能 |
| admin | 管理者 | ユーザー管理・設定変更が可能。プラン変更は不可 |
| accountant | 経理 | 全帳票・入金・レポートの閲覧・編集。ユーザー管理は不可 |
| sales | 営業 | 自分が担当する案件・帳票の作成・編集。入金管理は閲覧のみ |
| member | メンバー | 閲覧のみ |

---

### 2.2.3 customers（顧客・取引先）

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|----------|------|
| id | bigint | NO | auto | PK |
| uuid | uuid | NO | gen_random_uuid() | |
| tenant_id | bigint | NO | | FK → tenants.id |
| customer_type | varchar(10) | NO | 'client' | client(顧客) / vendor(仕入先) / both |
| company_name | varchar(255) | NO | | 会社名 |
| company_name_kana | varchar(255) | YES | | 会社名カナ |
| department | varchar(100) | YES | | 部署名 |
| title | varchar(50) | YES | | 役職 |
| contact_name | varchar(100) | YES | | 担当者名 |
| email | varchar(255) | YES | | メールアドレス |
| phone | varchar(20) | YES | | 電話番号 |
| fax | varchar(20) | YES | | FAX番号 |
| postal_code | varchar(8) | YES | | |
| prefecture | varchar(10) | YES | | |
| city | varchar(100) | YES | | |
| address_line1 | varchar(255) | YES | | |
| address_line2 | varchar(255) | YES | | |
| invoice_registration_number | varchar(14) | YES | | 適格請求書番号 |
| invoice_number_verified | boolean | NO | false | |
| invoice_number_verified_at | timestamp | YES | | |
| payment_terms_days | integer | YES | | 支払サイト（日数）NULLならテナントデフォルト |
| default_tax_rate | decimal(5,2) | YES | | NULLならテナントデフォルト |
| bank_name | varchar(100) | YES | | 振込先（仕入先の場合） |
| bank_branch_name | varchar(100) | YES | | |
| bank_account_type | smallint | YES | | |
| bank_account_number | varchar(10) | YES | | |
| bank_account_holder | varchar(100) | YES | | |
| tags | jsonb | NO | '[]' | タグ配列 ["IT", "東京"] |
| memo | text | YES | | 内部メモ |
| credit_score | integer | YES | | 0-100の与信スコア（★入金回収特化） |
| credit_score_updated_at | timestamp | YES | | |
| avg_payment_days | decimal(5,1) | YES | | 平均支払日数（★入金回収特化） |
| late_payment_rate | decimal(5,2) | YES | | 遅延率%（★入金回収特化） |
| total_outstanding | bigint | NO | 0 | 未回収残高（円）（★入金回収特化） |
| imported_from | varchar(50) | YES | | 移行元ツール名（★移行爆速） |
| external_id | varchar(255) | YES | | 移行元でのID（★移行爆速） |
| created_at | timestamp | NO | now() | |
| updated_at | timestamp | NO | now() | |
| deleted_at | timestamp | YES | | |

**インデックス:**
- `idx_customers_uuid` UNIQUE (uuid)
- `idx_customers_tenant` (tenant_id, deleted_at)
- `idx_customers_credit_score` (tenant_id, credit_score)
- `idx_customers_outstanding` (tenant_id, total_outstanding DESC)
- `idx_customers_external` (tenant_id, imported_from, external_id)

---

### 2.2.4 customer_contacts（顧客担当者）

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|----------|------|
| id | bigint | NO | auto | PK |
| customer_id | bigint | NO | | FK → customers.id |
| name | varchar(100) | NO | | 氏名 |
| email | varchar(255) | YES | | |
| phone | varchar(20) | YES | | |
| department | varchar(100) | YES | | |
| title | varchar(50) | YES | | |
| is_primary | boolean | NO | false | 主担当か |
| is_billing_contact | boolean | NO | false | 請求書送付先か |
| memo | text | YES | | |
| created_at | timestamp | NO | now() | |
| updated_at | timestamp | NO | now() | |

---

### 2.2.5 products（品目マスタ）

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|----------|------|
| id | bigint | NO | auto | PK |
| tenant_id | bigint | NO | | FK → tenants.id |
| code | varchar(50) | YES | | 品目コード |
| name | varchar(255) | NO | | 品目名 |
| description | text | YES | | 説明 |
| unit | varchar(20) | YES | | 単位（式/個/時間/人月 等） |
| unit_price | bigint | YES | | デフォルト単価（円） |
| tax_rate | decimal(5,2) | YES | | 税率（NULL=テナントデフォルト） |
| tax_rate_type | varchar(20) | NO | 'standard' | standard(10%) / reduced(8%) / exempt(0%) |
| category | varchar(100) | YES | | カテゴリ |
| sort_order | integer | NO | 0 | 表示順 |
| is_active | boolean | NO | true | |
| created_at | timestamp | NO | now() | |
| updated_at | timestamp | NO | now() | |

---

### 2.2.6 projects（案件）

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|----------|------|
| id | bigint | NO | auto | PK |
| uuid | uuid | NO | gen_random_uuid() | |
| tenant_id | bigint | NO | | FK → tenants.id |
| customer_id | bigint | NO | | FK → customers.id |
| assigned_user_id | bigint | YES | | FK → users.id（担当者） |
| project_number | varchar(50) | NO | | 案件番号（テナント内UNIQUE） |
| name | varchar(255) | NO | | 案件名 |
| status | varchar(30) | NO | 'negotiation' | ステータス（後述） |
| probability | integer | YES | | 受注確度(0-100%) |
| amount | bigint | YES | | 見込み金額（税抜・円） |
| cost | bigint | YES | | 原価（円） |
| start_date | date | YES | | 開始予定日 |
| end_date | date | YES | | 終了予定日 |
| description | text | YES | | 案件説明 |
| tags | jsonb | NO | '[]' | |
| custom_fields | jsonb | NO | '{}' | 業種別カスタムフィールド |
| imported_from | varchar(50) | YES | | （★移行爆速） |
| external_id | varchar(255) | YES | | （★移行爆速） |
| created_at | timestamp | NO | now() | |
| updated_at | timestamp | NO | now() | |
| deleted_at | timestamp | YES | | |

**ステータス遷移（ステートマシン）:**

```
negotiation（商談中）
  → won（受注）
  → lost（失注）

won（受注）
  → in_progress（進行中）
  → cancelled（キャンセル）

in_progress（進行中）
  → delivered（納品済）
  → cancelled

delivered（納品済）
  → invoiced（請求済）

invoiced（請求済）
  → paid（入金完了）
  → partially_paid（一部入金）
  → overdue（支払遅延）★入金回収特化

partially_paid（一部入金）
  → paid
  → overdue

overdue（支払遅延）★入金回収特化
  → paid
  → partially_paid
  → bad_debt（貸倒）

bad_debt（貸倒）
  → paid（回収できた場合の巻き戻し）

cancelled（キャンセル）
  → （終了状態）

lost（失注）
  → negotiation（再商談）
```

**インデックス:**
- `idx_projects_uuid` UNIQUE (uuid)
- `idx_projects_tenant_status` (tenant_id, status, deleted_at)
- `idx_projects_customer` (customer_id)
- `idx_projects_number` UNIQUE (tenant_id, project_number) WHERE deleted_at IS NULL

---

### 2.2.7 documents（帳票）

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|----------|------|
| id | bigint | NO | auto | PK |
| uuid | uuid | NO | gen_random_uuid() | |
| tenant_id | bigint | NO | | FK → tenants.id |
| project_id | bigint | YES | | FK → projects.id |
| customer_id | bigint | NO | | FK → customers.id |
| created_by_user_id | bigint | NO | | FK → users.id |
| document_type | varchar(20) | NO | | estimate / purchase_order / order_confirmation / delivery_note / invoice / receipt |
| document_number | varchar(50) | NO | | 帳票番号（テナント内・タイプ内UNIQUE） |
| status | varchar(20) | NO | 'draft' | draft / approved / sent / accepted / rejected / cancelled / locked |
| version | integer | NO | 1 | バージョン番号 |
| parent_document_id | bigint | YES | | FK → documents.id（変換元の帳票） |
| title | varchar(255) | YES | | 件名 |
| issue_date | date | NO | | 発行日 |
| due_date | date | YES | | 支払期日（請求書の場合） |
| valid_until | date | YES | | 有効期限（見積書の場合） |
| subtotal | bigint | NO | 0 | 小計（税抜） |
| tax_amount | bigint | NO | 0 | 消費税合計 |
| total_amount | bigint | NO | 0 | 合計（税込） |
| tax_summary | jsonb | NO | '[]' | 税率別集計 [{"rate":10,"subtotal":100000,"tax":10000}] |
| notes | text | YES | | 備考 |
| internal_memo | text | YES | | 社内メモ（帳票には出力しない） |
| sender_snapshot | jsonb | NO | '{}' | 発行時の自社情報スナップショット |
| recipient_snapshot | jsonb | NO | '{}' | 発行時の顧客情報スナップショット |
| pdf_url | varchar(500) | YES | | 生成済みPDFのR2 URL |
| pdf_generated_at | timestamp | YES | | |
| sent_at | timestamp | YES | | 送信日時 |
| sent_method | varchar(20) | YES | | email / postal / hand |
| locked_at | timestamp | YES | | ロック日時（電子帳簿保存法対応） |
| payment_status | varchar(20) | YES | | unpaid / partial / paid / overdue / bad_debt（請求書のみ）(★入金回収) |
| paid_amount | bigint | NO | 0 | 入金済み金額（★入金回収） |
| remaining_amount | bigint | NO | 0 | 未回収金額（★入金回収） |
| last_dunning_at | timestamp | YES | | 最終督促日時（★入金回収） |
| dunning_count | integer | NO | 0 | 督促回数（★入金回収） |
| is_recurring | boolean | NO | false | 定期請求か |
| recurring_rule_id | bigint | YES | | FK → recurring_rules.id |
| imported_from | varchar(50) | YES | | （★移行爆速） |
| external_id | varchar(255) | YES | | （★移行爆速） |
| created_at | timestamp | NO | now() | |
| updated_at | timestamp | NO | now() | |
| deleted_at | timestamp | YES | | |

**帳票ステータス遷移:**

```
draft（下書き）
  → approved（承認済） ※承認フロー有効時
  → sent（送信済）     ※承認フロー無効時

approved（承認済）
  → sent（送信済）
  → draft（差し戻し）

sent（送信済）
  → accepted（承諾済）  ※見積書のみ
  → rejected（却下）    ※見積書のみ
  → locked（ロック済）  ※送信後一定期間で自動ロック

cancelled（取消）
  → （終了状態）

locked（ロック済）
  → （変更不可。訂正する場合は新バージョンを作成）
```

**請求書の入金ステータス遷移（★入金回収特化）:**

```
unpaid（未入金）
  → partial（一部入金）   ※入金額 < 請求額
  → paid（入金完了）      ※入金額 >= 請求額
  → overdue（支払遅延）   ※支払期日超過のバッチ処理で自動遷移

partial（一部入金）
  → paid
  → overdue

overdue（支払遅延）
  → partial
  → paid
  → bad_debt（貸倒）      ※手動設定

bad_debt（貸倒）
  → paid（回収時）
```

**インデックス:**
- `idx_documents_uuid` UNIQUE (uuid)
- `idx_documents_tenant_type` (tenant_id, document_type, deleted_at)
- `idx_documents_number` UNIQUE (tenant_id, document_type, document_number) WHERE deleted_at IS NULL
- `idx_documents_project` (project_id)
- `idx_documents_customer` (customer_id)
- `idx_documents_payment_status` (tenant_id, payment_status, due_date) WHERE document_type = 'invoice'
- `idx_documents_due_date` (tenant_id, due_date) WHERE document_type = 'invoice' AND payment_status IN ('unpaid','partial','overdue')
- `idx_documents_external` (tenant_id, imported_from, external_id)

---

### 2.2.8 document_items（帳票明細行）

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|----------|------|
| id | bigint | NO | auto | PK |
| document_id | bigint | NO | | FK → documents.id |
| product_id | bigint | YES | | FK → products.id |
| sort_order | integer | NO | 0 | 表示順 |
| item_type | varchar(10) | NO | 'normal' | normal / subtotal / discount / section_header |
| name | varchar(255) | NO | | 品名 |
| description | text | YES | | 説明 |
| quantity | decimal(15,4) | NO | 1 | 数量 |
| unit | varchar(20) | YES | | 単位 |
| unit_price | bigint | NO | 0 | 単価（円） |
| amount | bigint | NO | 0 | 金額 = quantity × unit_price |
| tax_rate | decimal(5,2) | NO | 10.00 | 消費税率 |
| tax_rate_type | varchar(20) | NO | 'standard' | standard / reduced / exempt |
| tax_amount | bigint | NO | 0 | 消費税額 |

---

### 2.2.9 document_versions（帳票バージョン履歴）

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|----------|------|
| id | bigint | NO | auto | PK |
| document_id | bigint | NO | | FK → documents.id |
| version | integer | NO | | バージョン番号 |
| snapshot | jsonb | NO | | その時点の帳票データ全体 |
| pdf_url | varchar(500) | YES | | |
| changed_by_user_id | bigint | NO | | FK → users.id |
| change_reason | text | YES | | 変更理由 |
| created_at | timestamp | NO | now() | |

---

### 2.2.10 recurring_rules（定期請求ルール）

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|----------|------|
| id | bigint | NO | auto | PK |
| tenant_id | bigint | NO | | FK → tenants.id |
| customer_id | bigint | NO | | FK → customers.id |
| project_id | bigint | YES | | FK → projects.id |
| name | varchar(255) | NO | | ルール名 |
| frequency | varchar(10) | NO | 'monthly' | monthly / quarterly / yearly |
| generation_day | integer | NO | 1 | 生成日（1-28） |
| issue_day | integer | NO | 1 | 発行日 |
| next_generation_date | date | NO | | 次回生成予定日 |
| template_items | jsonb | NO | '[]' | 明細テンプレート |
| auto_send | boolean | NO | false | 自動送信するか |
| is_active | boolean | NO | true | |
| start_date | date | NO | | 開始日 |
| end_date | date | YES | | 終了日（NULLは無期限） |
| created_at | timestamp | NO | now() | |
| updated_at | timestamp | NO | now() | |

---

### 2.2.11 payment_records（入金記録）★入金回収特化

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|----------|------|
| id | bigint | NO | auto | PK |
| uuid | uuid | NO | gen_random_uuid() | |
| tenant_id | bigint | NO | | FK → tenants.id |
| document_id | bigint | NO | | FK → documents.id（請求書） |
| bank_statement_id | bigint | YES | | FK → bank_statements.id |
| amount | bigint | NO | | 入金額（円） |
| payment_date | date | NO | | 入金日 |
| payment_method | varchar(20) | NO | 'bank_transfer' | bank_transfer / cash / credit_card / other |
| matched_by | varchar(20) | NO | 'manual' | manual / ai_auto / ai_suggested |
| match_confidence | decimal(3,2) | YES | | AI消込の確信度(0.00-1.00) |
| memo | text | YES | | |
| recorded_by_user_id | bigint | NO | | FK → users.id |
| created_at | timestamp | NO | now() | |
| updated_at | timestamp | NO | now() | |

**インデックス:**
- `idx_payment_records_document` (document_id)
- `idx_payment_records_tenant_date` (tenant_id, payment_date)
- `idx_payment_records_bank_statement` (bank_statement_id)

---

### 2.2.12 bank_statements（銀行明細）★入金回収特化

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|----------|------|
| id | bigint | NO | auto | PK |
| tenant_id | bigint | NO | | FK → tenants.id |
| transaction_date | date | NO | | 取引日 |
| value_date | date | YES | | 起算日 |
| description | varchar(500) | NO | | 摘要 |
| payer_name | varchar(255) | YES | | 振込依頼人名 |
| amount | bigint | NO | | 金額 |
| balance | bigint | YES | | 残高 |
| bank_name | varchar(100) | YES | | 銀行名 |
| account_number | varchar(20) | YES | | 口座番号 |
| is_matched | boolean | NO | false | 消込済みか |
| matched_document_id | bigint | YES | | FK → documents.id |
| ai_suggested_document_id | bigint | YES | | AI提案の請求書ID |
| ai_match_confidence | decimal(3,2) | YES | | AI確信度 |
| ai_match_reason | text | YES | | AIの判断理由 |
| import_batch_id | varchar(50) | NO | | CSVインポート一括ID |
| raw_data | jsonb | YES | | 元CSVの生データ |
| created_at | timestamp | NO | now() | |
| updated_at | timestamp | NO | now() | |

**インデックス:**
- `idx_bank_statements_tenant_unmatched` (tenant_id, is_matched, transaction_date) WHERE is_matched = false
- `idx_bank_statements_tenant_date` (tenant_id, transaction_date)
- `idx_bank_statements_batch` (import_batch_id)

---

### 2.2.13 dunning_rules（督促ルール）★入金回収特化

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|----------|------|
| id | bigint | NO | auto | PK |
| tenant_id | bigint | NO | | FK → tenants.id |
| name | varchar(100) | NO | | ルール名 |
| trigger_days_after_due | integer | NO | | 支払期日後N日で発動 |
| action_type | varchar(20) | NO | | email / internal_alert / both |
| email_template_subject | varchar(255) | YES | | メール件名テンプレート |
| email_template_body | text | YES | | メール本文テンプレート（変数埋め込み対応） |
| send_to | varchar(20) | NO | 'billing_contact' | billing_contact / primary_contact / custom_email |
| custom_email | varchar(255) | YES | | |
| is_active | boolean | NO | true | |
| sort_order | integer | NO | 0 | 実行優先順（複数ルールの順序） |
| max_dunning_count | integer | NO | 3 | この段階での最大送信回数 |
| interval_days | integer | NO | 7 | 繰り返し間隔（日） |
| escalation_rule_id | bigint | YES | | FK → dunning_rules.id（エスカレーション先） |
| created_at | timestamp | NO | now() | |
| updated_at | timestamp | NO | now() | |

**テンプレート変数一覧:**
- `{{customer_name}}` - 取引先名
- `{{document_number}}` - 請求書番号
- `{{total_amount}}` - 請求金額
- `{{remaining_amount}}` - 未入金額
- `{{due_date}}` - 支払期日
- `{{overdue_days}}` - 遅延日数
- `{{company_name}}` - 自社名
- `{{bank_info}}` - 振込先情報

**デフォルト督促シナリオ（初期データ）:**

| ステップ | 支払期日後 | アクション | メッセージトーン |
|---------|-----------|-----------|----------------|
| 1. やさしいリマインド | 1日 | email | 「お支払いの確認をお願いいたします」 |
| 2. 通常督促 | 7日 | email + 社内アラート | 「お支払い期日を過ぎております」 |
| 3. 強い督促 | 14日 | email + 社内アラート | 「至急のお支払いをお願いいたします」 |
| 4. 最終通知 | 30日 | email + 社内アラート | 「最終のご連絡」 |

---

### 2.2.14 dunning_logs（督促履歴）★入金回収特化

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|----------|------|
| id | bigint | NO | auto | PK |
| tenant_id | bigint | NO | | FK → tenants.id |
| document_id | bigint | NO | | FK → documents.id（請求書） |
| dunning_rule_id | bigint | NO | | FK → dunning_rules.id |
| customer_id | bigint | NO | | FK → customers.id |
| action_type | varchar(20) | NO | | email / internal_alert |
| sent_to_email | varchar(255) | YES | | 送信先メール |
| email_subject | varchar(255) | YES | | 実際に送信した件名 |
| email_body | text | YES | | 実際に送信した本文 |
| status | varchar(20) | NO | | sent / failed / opened / clicked |
| overdue_days | integer | NO | | 遅延日数（送信時点） |
| remaining_amount | bigint | NO | | 未回収額（送信時点） |
| created_at | timestamp | NO | now() | |

---

### 2.2.15 credit_score_histories（与信スコア履歴）★入金回収特化

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|----------|------|
| id | bigint | NO | auto | PK |
| tenant_id | bigint | NO | | FK → tenants.id |
| customer_id | bigint | NO | | FK → customers.id |
| score | integer | NO | | 0-100 |
| factors | jsonb | NO | '{}' | スコア算出根拠 |
| calculated_at | timestamp | NO | now() | |

**与信スコア算出ロジック（100点満点）:**

```
基本スコア = 50

加点要素:
  +20: 直近6ヶ月の支払いが全て期日内
  +15: 取引期間が1年以上
  +10: 平均支払日数が支払サイト-5日以内（早払い傾向）
  +5:  取引金額累計が100万円以上

減点要素:
  -30: 直近3ヶ月に30日以上の遅延あり
  -20: 直近6ヶ月に14日以上の遅延が2回以上
  -15: 遅延率が30%以上
  -10: 直近6ヶ月に7日以上の遅延が1回
  -5:  平均支払日数がサイト+7日以上

最低0、最高100でクランプ
```

---

### 2.2.16 import_jobs（移行ジョブ）★移行爆速

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|----------|------|
| id | bigint | NO | auto | PK |
| uuid | uuid | NO | gen_random_uuid() | |
| tenant_id | bigint | NO | | FK → tenants.id |
| user_id | bigint | NO | | FK → users.id |
| source_type | varchar(30) | NO | | board / freee / misoca / makeleaps / excel / csv_generic |
| status | varchar(20) | NO | 'pending' | pending / parsing / mapping / previewing / importing / completed / failed |
| file_url | varchar(500) | NO | | アップロードファイルのR2 URL |
| file_name | varchar(255) | NO | | 元ファイル名 |
| file_size | bigint | NO | | ファイルサイズ(bytes) |
| parsed_data | jsonb | YES | | パース後の構造化データ |
| column_mapping | jsonb | YES | | カラムマッピング設定（AIの提案→ユーザー確認済み） |
| preview_data | jsonb | YES | | プレビュー（先頭10件） |
| import_stats | jsonb | YES | | {total:100, success:98, skipped:1, error:1} |
| error_details | jsonb | YES | | エラー行の詳細 [{row:5, field:"email", error:"format"}] |
| ai_mapping_confidence | decimal(3,2) | YES | | AIマッピングの全体確信度 |
| started_at | timestamp | YES | | |
| completed_at | timestamp | YES | | |
| created_at | timestamp | NO | now() | |
| updated_at | timestamp | NO | now() | |

**移行ステータス遷移:**

```
pending（アップロード完了）
  → parsing（ファイル解析中）

parsing
  → mapping（カラムマッピング中）
  → failed（パースエラー）

mapping（AI自動マッピング→ユーザー確認待ち）
  → previewing（プレビュー生成中）

previewing
  → importing（ユーザーが確認後、インポート実行）
  → mapping（マッピング修正）

importing
  → completed
  → failed
```

**対応インポート形式:**

| source_type | 対応ファイル | 取り込み対象データ |
|-------------|------------|------------------|
| board | CSVエクスポート | 顧客・案件・見積書・請求書 |
| freee | CSV / API | 取引先・請求書・入金 |
| misoca | CSVエクスポート | 取引先・請求書 |
| makeleaps | CSVエクスポート | 取引先・見積書・請求書 |
| excel | .xlsx / .xls | AI自動カラム判定で汎用取り込み |
| csv_generic | .csv | AI自動カラム判定で汎用取り込み |

---

### 2.2.17 import_column_definitions（移行カラム定義マスタ）★移行爆速

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|----------|------|
| id | bigint | NO | auto | PK |
| source_type | varchar(30) | NO | | board / freee / misoca / makeleaps |
| source_column_name | varchar(255) | NO | | 元システムのカラム名 |
| target_table | varchar(50) | NO | | マッピング先テーブル |
| target_column | varchar(50) | NO | | マッピング先カラム |
| transform_rule | varchar(50) | YES | | 変換ルール（date_jp / amount_comma / etc） |
| is_required | boolean | NO | false | |

**事前定義マッピングルール（boardの例）:**

```json
[
  {"source": "顧客名", "target_table": "customers", "target_column": "company_name"},
  {"source": "メールアドレス", "target_table": "customers", "target_column": "email"},
  {"source": "案件名", "target_table": "projects", "target_column": "name"},
  {"source": "見積金額", "target_table": "documents", "target_column": "total_amount", "transform": "amount_comma"},
  {"source": "請求日", "target_table": "documents", "target_column": "issue_date", "transform": "date_jp"},
  {"source": "支払期日", "target_table": "documents", "target_column": "due_date", "transform": "date_jp"},
  {"source": "入金状況", "target_table": "documents", "target_column": "payment_status", "transform": "status_map"}
]
```

---

### 2.2.18 industry_templates（業種テンプレート）

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|----------|------|
| id | bigint | NO | auto | PK |
| code | varchar(50) | NO | | general / it / construction / design / consulting / legal |
| name | varchar(100) | NO | | 表示名（日本語） |
| labels | jsonb | NO | '{}' | 用語マッピング {"project":"プロジェクト","案件":"工事案件"} |
| default_products | jsonb | NO | '[]' | デフォルト品目 |
| default_statuses | jsonb | NO | '[]' | デフォルトステータス名 |
| document_templates | jsonb | NO | '{}' | 帳票レイアウト設定 |
| tax_settings | jsonb | NO | '{}' | 税率デフォルト |
| sort_order | integer | NO | 0 | |
| is_active | boolean | NO | true | |

---

### 2.2.19 notifications（通知）

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|----------|------|
| id | bigint | NO | auto | PK |
| tenant_id | bigint | NO | | FK → tenants.id |
| user_id | bigint | NO | | FK → users.id（通知先） |
| notification_type | varchar(50) | NO | | 通知種別（後述） |
| title | varchar(255) | NO | | |
| body | text | YES | | |
| data | jsonb | NO | '{}' | 関連データ {document_id, customer_id, etc} |
| is_read | boolean | NO | false | |
| read_at | timestamp | YES | | |
| created_at | timestamp | NO | now() | |

**通知種別一覧:**

| notification_type | トリガー | デフォルト通知先 |
|-------------------|---------|----------------|
| invoice_due_soon | 支払期日3日前 | owner, accountant |
| invoice_overdue | 支払期日超過 | owner, accountant |
| payment_received | 入金消込完了 | owner, accountant, 案件担当者 |
| dunning_sent | 督促メール送信 | owner, accountant |
| dunning_failed | 督促メール送信失敗 | owner, admin |
| import_completed | データ移行完了 | 実行者 |
| import_failed | データ移行失敗 | 実行者 |
| document_approved | 帳票承認完了 | 作成者 |
| recurring_generated | 定期請求書生成 | owner, accountant |
| credit_score_dropped | 与信スコア低下(★) | owner, accountant |
| large_overdue_alert | 高額未回収アラート(★) | owner |

---

### 2.2.20 audit_logs（操作ログ）

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|----------|------|
| id | bigint | NO | auto | PK |
| tenant_id | bigint | NO | | FK → tenants.id |
| user_id | bigint | YES | | FK → users.id（NULLはシステム操作） |
| action | varchar(50) | NO | | create / update / delete / send / lock / import / export / login |
| resource_type | varchar(50) | NO | | document / customer / project / payment / user / setting |
| resource_id | bigint | YES | | |
| changes | jsonb | YES | | 変更差分 {"field": {"old":"A","new":"B"}} |
| ip_address | inet | YES | | |
| user_agent | varchar(500) | YES | | |
| created_at | timestamp | NO | now() | |

**パーティショニング:** created_atで月次パーティション（データ量増加時に有効化）

---

## 2.3 電子帳簿保存法対応の設計方針

| 要件 | 実装方法 |
|------|---------|
| タイムスタンプ要件 | documents.locked_at に保存時刻を記録。将来的には認定タイムスタンプ局との連携を検討 |
| 検索要件 | 日付(issue_date)、金額(total_amount)、取引先名(customers.company_name)で検索可能 |
| 改ざん防止 | locked状態の帳票は更新不可。訂正は新バージョンを作成。audit_logsで全操作を記録 |
| 書類間の関連性 | parent_document_idで変換元を追跡。project_idで案件単位の紐づけ |

---

# 第3部：API設計

## 3.1 共通仕様

| 項目 | 仕様 |
|------|------|
| ベースURL | `https://api.uketori.jp/v1` |
| 認証 | Authorization: Bearer {JWT} |
| レスポンス形式 | JSON |
| ページネーション | `?page=1&per_page=25` (最大100) |
| ソート | `?sort=created_at&order=desc` |
| フィルタ | `?filter[status]=overdue&filter[customer_id]=123` |
| エラー形式 | `{"error":{"code":"validation_error","message":"...","details":[...]}}` |
| レートリミット | 100リクエスト/分/ユーザー |

### HTTPステータスコード

| コード | 用途 |
|--------|------|
| 200 | 成功（GET, PATCH） |
| 201 | 作成成功（POST） |
| 204 | 削除成功（DELETE） |
| 400 | バリデーションエラー |
| 401 | 認証エラー |
| 403 | 認可エラー（権限不足） |
| 404 | リソース未発見 |
| 409 | 競合（楽観的ロック等） |
| 422 | 処理不能（ビジネスロジックエラー） |
| 429 | レートリミット超過 |
| 500 | サーバーエラー |

## 3.2 認証API

```
POST   /auth/sign_in          ログイン → JWT発行
POST   /auth/refresh           トークンリフレッシュ
DELETE /auth/sign_out          ログアウト（トークン無効化）
POST   /auth/password/reset    パスワードリセット要求
PATCH  /auth/password/update   パスワード更新
POST   /auth/invitation/accept 招待受諾
```

## 3.3 顧客API

```
GET    /customers              一覧取得（フィルタ・ソート・ページネーション）
POST   /customers              新規作成
GET    /customers/:uuid        詳細取得
PATCH  /customers/:uuid        更新
DELETE /customers/:uuid        論理削除
GET    /customers/:uuid/documents   顧客の帳票一覧
GET    /customers/:uuid/credit_history  与信スコア履歴（★入金回収）
POST   /customers/:uuid/verify_invoice_number  適格請求書番号検証
```

### GET /customers フィルタ可能パラメータ

| パラメータ | 型 | 説明 |
|-----------|-----|------|
| filter[customer_type] | string | client / vendor / both |
| filter[tags] | string[] | タグ（OR検索） |
| filter[q] | string | 会社名・カナの部分一致検索 |
| filter[credit_score_min] | integer | 与信スコア最小値（★入金回収） |
| filter[credit_score_max] | integer | 与信スコア最大値（★入金回収） |
| filter[has_overdue] | boolean | 支払遅延ありのみ（★入金回収） |
| filter[outstanding_min] | integer | 未回収残高最小値（★入金回収） |
| sort | string | company_name / credit_score / total_outstanding / created_at |

## 3.4 案件API

```
GET    /projects               一覧取得
POST   /projects               新規作成
GET    /projects/:uuid         詳細取得
PATCH  /projects/:uuid         更新
DELETE /projects/:uuid         論理削除
PATCH  /projects/:uuid/status  ステータス変更
GET    /projects/:uuid/documents  案件の帳票一覧
GET    /projects/pipeline      パイプライン表示用集計データ
```

### GET /projects/pipeline レスポンス

```json
{
  "pipeline": [
    {
      "status": "negotiation",
      "label": "商談中",
      "count": 5,
      "total_amount": 2500000,
      "projects": [
        {"uuid":"...","name":"Webサイト制作","customer_name":"A社","amount":500000,"probability":60}
      ]
    },
    {
      "status": "won",
      "label": "受注",
      "count": 3,
      "total_amount": 1800000,
      "projects": [...]
    }
  ]
}
```

## 3.5 帳票API

```
GET    /documents                    一覧取得
POST   /documents                    新規作成
GET    /documents/:uuid              詳細取得
PATCH  /documents/:uuid              更新
DELETE /documents/:uuid              論理削除
POST   /documents/:uuid/duplicate    複製
POST   /documents/:uuid/convert      帳票変換（見積→請求等）
POST   /documents/:uuid/approve      承認
POST   /documents/:uuid/reject       却下（差し戻し）
POST   /documents/:uuid/send         メール送信
POST   /documents/:uuid/lock         ロック（電子帳簿保存法）
GET    /documents/:uuid/pdf          PDF取得（生成済みのURLまたは新規生成）
GET    /documents/:uuid/versions     バージョン履歴
POST   /documents/bulk_generate      一括請求書生成
POST   /documents/:uuid/ai_suggest   AI見積提案（★AI機能）
```

### POST /documents 作成リクエスト

```json
{
  "document_type": "invoice",
  "project_id": "project-uuid-here",
  "customer_id": "customer-uuid-here",
  "issue_date": "2026-02-25",
  "due_date": "2026-03-31",
  "title": "Webサイト制作費用",
  "notes": "お振込みの際は請求書番号をご記載ください",
  "items": [
    {
      "name": "Webサイトデザイン",
      "quantity": 1,
      "unit": "式",
      "unit_price": 500000,
      "tax_rate_type": "standard"
    },
    {
      "name": "コーディング",
      "quantity": 40,
      "unit": "時間",
      "unit_price": 5000,
      "tax_rate_type": "standard"
    }
  ]
}
```

**金額計算ロジック（サーバーサイドで必ず再計算）:**

```ruby
# 各明細行
item.amount = (item.quantity * item.unit_price).floor

# 税率別集計（インボイス対応：税率ごとに一括計算）
tax_groups = items.group_by(&:tax_rate)
tax_summary = tax_groups.map do |rate, group_items|
  subtotal = group_items.sum(&:amount)
  tax = (subtotal * rate / 100).floor  # 端数切捨て
  { rate: rate, subtotal: subtotal, tax: tax }
end

# 合計
document.subtotal = tax_summary.sum { |g| g[:subtotal] }
document.tax_amount = tax_summary.sum { |g| g[:tax] }
document.total_amount = document.subtotal + document.tax_amount
document.remaining_amount = document.total_amount - document.paid_amount
```

### POST /documents/:uuid/convert 帳票変換

```json
{
  "target_type": "invoice",
  "copy_items": true,
  "issue_date": "2026-03-01",
  "due_date": "2026-03-31"
}
```

**変換ルール:**

| 変換元 | 変換先 | 自動設定 |
|--------|--------|---------|
| estimate → invoice | 見積→請求 | 品目コピー。parent_document_id設定 |
| estimate → purchase_order | 見積→発注 | 品目コピー |
| purchase_order → delivery_note | 発注→納品 | 品目コピー |
| purchase_order → invoice | 発注→請求 | 品目コピー |
| invoice → receipt | 請求→領収 | 金額コピー。入金完了済みの場合のみ |

## 3.6 入金回収API ★入金回収特化

```
GET    /payments                         入金記録一覧
POST   /payments                         入金記録作成（手動消込）
DELETE /payments/:id                      入金記録取消

POST   /bank_statements/import            銀行明細CSVアップロード
GET    /bank_statements                   銀行明細一覧
GET    /bank_statements/unmatched         未消込一覧
POST   /bank_statements/:id/match         手動消込
POST   /bank_statements/ai_match          AI一括消込（★）
POST   /bank_statements/:id/ai_suggest    AI消込候補取得（★）

GET    /dunning/rules                     督促ルール一覧
POST   /dunning/rules                     督促ルール作成
PATCH  /dunning/rules/:id                 督促ルール更新
DELETE /dunning/rules/:id                 督促ルール削除
GET    /dunning/logs                      督促履歴一覧
POST   /dunning/execute                   督促手動実行

GET    /collection/dashboard              回収ダッシュボード（★）
GET    /collection/aging_report           売掛金年齢表（★）
GET    /collection/forecast               入金予測（★）
```

### POST /bank_statements/import 銀行明細CSV取込

**リクエスト:** multipart/form-data
- `file`: CSVファイル
- `bank_type`: `generic / mufg / smbc / mizuho / rakuten / jibun`（銀行別フォーマット自動判定）

**処理フロー:**
1. CSVパース（Shift_JIS / UTF-8自動判定）
2. 銀行フォーマットに基づくカラムマッピング
3. 重複チェック（同一日付・金額・摘要の組み合わせ）
4. DB保存
5. AI自動マッチング実行（SolidQueueで非同期）
6. 結果返却

**レスポンス (200):**
```json
{
  "import_batch_id": "batch-uuid",
  "total_records": 50,
  "new_records": 45,
  "duplicate_skipped": 5,
  "auto_matched": 30,
  "needs_review": 10,
  "unmatched": 5,
  "matched_details": [
    {
      "bank_statement_id": 123,
      "payer_name": "カ）エービーシー",
      "amount": 550000,
      "matched_document_number": "INV-202603-001",
      "confidence": 0.95,
      "match_reason": "金額完全一致＋振込名義が顧客名と部分一致"
    }
  ]
}
```

### AI消込マッチングロジック（★入金回収特化の核心）

```
入力: 銀行明細1件(payer_name, amount, date) + 未消込請求書リスト

ステップ1: ルールベースフィルタリング
  - 金額完全一致の請求書を候補に抽出
  - 金額±1円の候補も含める（振込手数料差額考慮）

ステップ2: 名義マッチング（ファジーマッチ）
  - payer_nameを正規化（カタカナ変換、株式会社→カ）等）
  - 顧客マスタのcompany_name, company_name_kanaと比較
  - Levenshtein距離 + 前方一致 + 部分一致でスコア算出

ステップ3: AI補完（Claude API）
  - ルールベースで確信度0.7未満の候補をAIに渡す
  - プロンプト: 「以下の振込情報と請求書リストから最も確からしい組み合わせを判定してください」
  - AIの回答から候補とconfidenceを取得

ステップ4: 結果分類
  - confidence >= 0.90: auto_matched（自動消込）
  - 0.70 <= confidence < 0.90: needs_review（要確認。候補を提示）
  - confidence < 0.70: unmatched（マッチなし）

ステップ5: 自動消込の実行（auto_matchedのみ）
  - payment_records作成
  - documents.paid_amount += 入金額
  - documents.remaining_amount 再計算
  - documents.payment_status 更新
  - customers.total_outstanding 再計算
```

### GET /collection/dashboard 回収ダッシュボード

**レスポンス:**
```json
{
  "summary": {
    "total_outstanding": 5500000,
    "overdue_amount": 1200000,
    "overdue_count": 8,
    "overdue_rate": 21.8,
    "collected_this_month": 3200000,
    "collection_rate_this_month": 89.5,
    "avg_collection_days": 32.5,
    "bad_debt_amount": 0
  },
  "aging": {
    "current": {"count": 15, "amount": 3000000},
    "days_1_30": {"count": 5, "amount": 1300000},
    "days_31_60": {"count": 2, "amount": 700000},
    "days_61_90": {"count": 1, "amount": 500000},
    "days_over_90": {"count": 0, "amount": 0}
  },
  "at_risk_customers": [
    {
      "customer_uuid": "...",
      "company_name": "株式会社XYZ",
      "credit_score": 35,
      "outstanding": 800000,
      "oldest_overdue_days": 45,
      "trend": "declining"
    }
  ],
  "upcoming_payments": [
    {
      "due_date": "2026-03-05",
      "total_amount": 1500000,
      "document_count": 3
    }
  ],
  "collection_trend": [
    {"month": "2025-10", "billed": 4000000, "collected": 3800000, "rate": 95.0},
    {"month": "2025-11", "billed": 4500000, "collected": 4200000, "rate": 93.3},
    {"month": "2025-12", "billed": 5000000, "collected": 4500000, "rate": 90.0}
  ]
}
```

### GET /collection/aging_report 売掛金年齢表（★入金回収の核心レポート）

**レスポンス:**
```json
{
  "as_of_date": "2026-02-25",
  "customers": [
    {
      "customer_uuid": "...",
      "company_name": "A株式会社",
      "credit_score": 85,
      "current": 500000,
      "days_1_30": 0,
      "days_31_60": 0,
      "days_61_90": 0,
      "days_over_90": 0,
      "total": 500000
    },
    {
      "customer_uuid": "...",
      "company_name": "B株式会社",
      "credit_score": 42,
      "current": 200000,
      "days_1_30": 300000,
      "days_31_60": 500000,
      "days_61_90": 0,
      "days_over_90": 0,
      "total": 1000000
    }
  ],
  "totals": {
    "current": 3000000,
    "days_1_30": 1300000,
    "days_31_60": 700000,
    "days_61_90": 500000,
    "days_over_90": 0,
    "grand_total": 5500000
  }
}
```

## 3.7 移行API ★移行爆速

```
POST   /imports                    移行ジョブ作成（ファイルアップロード）
GET    /imports/:uuid              ジョブ状態取得
GET    /imports/:uuid/preview      プレビュー取得（先頭10件）
PATCH  /imports/:uuid/mapping      カラムマッピング確認・修正
POST   /imports/:uuid/execute      インポート実行
GET    /imports/:uuid/result       結果取得
POST   /imports/ai_detect_format   AI形式自動判定（★）
```

### POST /imports 移行ジョブ作成

**リクエスト:** multipart/form-data
- `file`: CSV / XLSX ファイル
- `source_type`: `board / freee / misoca / makeleaps / excel / csv_generic / auto`
- `data_type`: `customers / documents / all`

**source_type=auto の場合の処理（★移行爆速の核心）:**

```
1. ファイルのヘッダー行を抽出
2. 既知フォーマット（board, freee, misoca, makeleaps）のカラム名パターンとマッチング
3. パターン一致しない場合 → Claude APIに送信
   プロンプト: 「以下のCSVヘッダーからデータ形式を判定し、各カラムが顧客名/金額/日付/...
   のどれに該当するかマッピングしてください」
4. AIの回答からcolumn_mappingを生成
5. ユーザーにプレビュー＋マッピング確認画面を表示
```

### 移行ウィザードのUIフロー（★移行爆速）

```
Step 1: ファイルアップロード
  - ドラッグ＆ドロップエリア
  - 移行元ツール選択（auto推奨）
  - 対応フォーマットの説明リンク

Step 2: AI自動マッピング結果の確認（3-5秒で表示）
  - 左列: 元ファイルのカラム名 + サンプルデータ
  - 右列: ウケトリのカラム（ドロップダウンで変更可）
  - 確信度バーの表示（緑/黄/赤）
  - 「スキップ」ボタン（不要なカラム）

Step 3: プレビュー
  - 先頭10件のデータプレビュー（テーブル表示）
  - エラー行のハイライト
  - 「問題なし」→ インポート実行

Step 4: 実行＆結果
  - プログレスバー表示
  - 完了後: 成功件数/スキップ件数/エラー件数
  - エラー詳細のCSVダウンロード
```

## 3.8 AI機能API

```
POST   /ai/estimate_suggestion     AI見積提案
POST   /ai/bank_match              AI入金消込（3.6と同一）
POST   /ai/revenue_forecast        AI売上予測
POST   /ai/ocr                     AI書類OCR
GET    /ai/customer_analysis/:uuid AI取引先分析
```

### POST /ai/estimate_suggestion AI見積提案

**リクエスト:**
```json
{
  "customer_id": "customer-uuid",
  "project_description": "コーポレートサイトリニューアル",
  "hints": ["レスポンシブ対応", "CMS導入", "5ページ構成"]
}
```

**処理ロジック:**
1. 同一顧客の過去見積書を最大10件取得
2. 類似案件（project descriptionの類似度）の見積書を最大10件取得
3. Claude APIに送信:「過去の見積データを参考に、以下の案件に最適な見積明細を提案してください」
4. AI回答をパースして品目リストとして返却

**レスポンス:**
```json
{
  "suggestions": [
    {"name": "デザイン制作", "quantity": 1, "unit": "式", "unit_price": 400000, "reason": "過去3件の類似案件の平均単価"},
    {"name": "コーディング（レスポンシブ）", "quantity": 5, "unit": "ページ", "unit_price": 80000, "reason": "CMS導入込みの相場"},
    {"name": "CMS構築（WordPress）", "quantity": 1, "unit": "式", "unit_price": 200000, "reason": "顧客Aへの過去提案実績"}
  ],
  "estimated_total": 1000000,
  "confidence": 0.78,
  "reference_documents": ["EST-202501-003", "EST-202412-008"]
}
```

### POST /ai/revenue_forecast AI売上予測

**処理ロジック:**
1. 過去12ヶ月の月次売上データ取得
2. 現在のパイプライン（negotiation + won案件の金額×確度）
3. 定期請求ルールからの確定売上
4. Claude APIに送信して自然言語コメント生成
5. 統計モデル（線形回帰ベース）で数値予測

---

# 第4部：画面仕様

## 4.1 画面一覧

| # | 画面名 | パス | 認証 | ロール |
|---|--------|------|------|--------|
| 1 | ログイン | /login | 不要 | - |
| 2 | パスワードリセット | /password/reset | 不要 | - |
| 3 | ダッシュボード | /dashboard | 必要 | 全ロール |
| 4 | **回収ダッシュボード** | /collection | 必要 | owner,admin,accountant |
| 5 | 顧客一覧 | /customers | 必要 | 全ロール |
| 6 | 顧客詳細 | /customers/:uuid | 必要 | 全ロール |
| 7 | 顧客作成・編集 | /customers/:uuid/edit | 必要 | owner〜sales |
| 8 | 案件一覧（リスト/カンバン） | /projects | 必要 | 全ロール |
| 9 | 案件詳細 | /projects/:uuid | 必要 | 全ロール |
| 10 | 案件作成・編集 | /projects/:uuid/edit | 必要 | owner〜sales |
| 11 | 帳票一覧 | /documents?type=invoice | 必要 | 全ロール |
| 12 | 帳票作成・編集 | /documents/:uuid/edit | 必要 | owner〜sales |
| 13 | 帳票プレビュー | /documents/:uuid/preview | 必要 | 全ロール |
| 14 | 入金一覧 | /payments | 必要 | owner,admin,accountant |
| 15 | **銀行明細取込・AI消込** | /payments/bank-import | 必要 | owner,admin,accountant |
| 16 | **督促管理** | /dunning | 必要 | owner,admin,accountant |
| 17 | **売掛金年齢表** | /collection/aging | 必要 | owner,admin,accountant |
| 18 | レポート | /reports | 必要 | owner,admin,accountant |
| 19 | **データ移行ウィザード** | /import | 必要 | owner,admin |
| 20 | 設定 - 自社情報 | /settings/company | 必要 | owner,admin |
| 21 | 設定 - ユーザー管理 | /settings/users | 必要 | owner,admin |
| 22 | 設定 - 業種テンプレート | /settings/industry | 必要 | owner,admin |
| 23 | 設定 - 督促ルール | /settings/dunning | 必要 | owner,admin |
| 24 | 設定 - 通知 | /settings/notifications | 必要 | 全ロール |
| 25 | 設定 - 請求・プラン | /settings/billing | 必要 | owner |

## 4.2 主要画面の詳細仕様

### 4.2.1 ダッシュボード (/dashboard)

**レイアウト:**
```
┌───────────────────────────────────────────────┐
│ ヘッダー: 「おはようございます、鈴木さん」       │
│ 期間切替: 今月 | 今四半期 | 今年度              │
├───────────────┬───────────────────────────────┤
│  KPIカード×4  │  KPIカード×4                   │
│  ┌──────────┐│  ┌──────────┐ ┌──────────┐    │
│  │今月売上   ││  │未回収金額 │ │回収率    │    │
│  │¥3,200,000││  │¥1,200,000│ │89.5%     │    │
│  │▲12% 前月比││  │★8件遅延  │ │▼2.1% 前月│    │
│  └──────────┘│  └──────────┘ └──────────┘    │
├───────────────┴───────────────────────────────┤
│ ★入金回収アラート（赤背景、遅延件数0でない時）  │
│ 「8件の請求書が支払期日を超過しています」        │
│ [回収ダッシュボードを確認 →]                    │
├───────────────────────┬─────────────────────────┤
│ 売上推移グラフ（棒+線）│ 入金予定カレンダー      │
│                       │ 3/5: ¥500,000 (A社)    │
│                       │ 3/10: ¥300,000 (B社)   │
├───────────────────────┼─────────────────────────┤
│ AI売上予測             │ 最近の取引一覧          │
│ 「来月の売上予測:      │ (直近10件の帳票操作)    │
│  ¥4,100,000」         │                         │
├───────────────────────┴─────────────────────────┤
│ 案件パイプライン（横棒グラフ）                    │
└───────────────────────────────────────────────────┘
```

### 4.2.2 回収ダッシュボード (/collection) ★入金回収特化

**レイアウト:**
```
┌───────────────────────────────────────────────┐
│ ヘッダー: 「入金回収管理」                       │
│ [銀行明細を取り込む] [督促を実行]                │
├───────────────────────────────────────────────┤
│ KPIカード: 未回収合計 | 遅延金額 | 回収率 | DSO   │
├───────────────────────────────────────────────┤
│ ★ 売掛金年齢表（エイジングチャート）             │
│ ┌────────┬────────┬────────┬────────┬────────┐│
│ │ 期限内  │ 1-30日 │31-60日 │61-90日 │ 90日超 ││
│ │¥3.0M   │¥1.3M  │¥0.7M  │¥0.5M  │ ¥0    ││
│ │ (緑)   │ (黄)   │ (橙)   │ (赤)   │ (濃赤) ││
│ └────────┴────────┴────────┴────────┴────────┘│
├───────────────────────────────────────────────┤
│ ★ 要注意取引先一覧                              │
│ | 取引先名 | 与信スコア | 未回収額 | 最長遅延日数 | │
│ | B社      | 35 (危険)  | ¥800K   | 45日        | │
│ | C社      | 52 (注意)  | ¥500K   | 22日        | │
│ [詳細を見る] [督促メールを送信]                   │
├───────────────────────────────────────────────┤
│ 回収トレンドグラフ（月次: 請求額 vs 回収額）      │
├───────────────────────────────────────────────┤
│ 未消込の銀行明細（未処理があれば表示）            │
│ 「5件の未消込明細があります」 [AI消込を実行 →]   │
└───────────────────────────────────────────────┘
```

### 4.2.3 銀行明細取込・AI消込 (/payments/bank-import) ★入金回収特化

**フロー:**
```
Step 1: CSVアップロード
  ┌──────────────────────────────────────┐
  │  ┌────────────────────────────────┐  │
  │  │   CSVファイルをドラッグ＆ドロップ │  │
  │  │   または [ファイルを選択]        │  │
  │  └────────────────────────────────┘  │
  │  銀行選択: [三菱UFJ▼] ※自動判定可   │
  │  [取り込む]                          │
  └──────────────────────────────────────┘

Step 2: AI消込結果（3-10秒の処理後）
  ┌──────────────────────────────────────┐
  │ 結果サマリー:                         │
  │ ✅ 自動消込: 30件  ⚠️ 要確認: 10件   │
  │ ❌ 未マッチ: 5件                      │
  ├──────────────────────────────────────┤
  │ ✅ 自動消込済み一覧（折りたたみ）      │
  │ | 振込人    | 金額     | →請求書No   | │
  │ | カ)ABC   | ¥550,000 | INV-001 95% | │
  ├──────────────────────────────────────┤
  │ ⚠️ 要確認一覧                        │
  │ | 振込人   | 金額     | AI候補       | │
  │ | ﾔﾏﾀﾞ ﾀﾛ | ¥100,000 | INV-005 72% | │
  │ |          |          | INV-008 65% | │
  │ | → [INV-005に消込] [別の請求書] [ス  │
  │ |   キップ]                           │
  ├──────────────────────────────────────┤
  │ ❌ 未マッチ一覧                       │
  │ | 振込人  | 金額    | [手動で消込]    │
  └──────────────────────────────────────┘
  │ [確定する]                             │
```

### 4.2.4 データ移行ウィザード (/import) ★移行爆速

**フロー:**
```
Step 1: 移行元の選択（大きなアイコンボタン）
  ┌──────────────────────────────────────┐
  │ 「今お使いのツールからデータを移行」     │
  │                                        │
  │ [📋 board]  [💰 freee]  [📄 Misoca]  │
  │ [📝 MakeLeaps] [📊 Excel/CSV]        │
  │                                        │
  │ ※ 各ボタンの下に「対応エクスポート手順  │
  │   はこちら」のリンク                    │
  └──────────────────────────────────────┘

Step 2: ファイルアップロード
  ┌──────────────────────────────────────┐
  │ boardからの移行                        │
  │ 📖 エクスポート手順:                   │
  │ 1. boardにログイン                     │
  │ 2. 設定→データエクスポートを選択       │
  │ 3. CSVをダウンロード                   │
  │                                        │
  │ [CSVファイルをドロップ]                │
  └──────────────────────────────────────┘

Step 3: AIマッピング確認（3-5秒で自動完了）
  ┌──────────────────────────────────────┐
  │ ✅ カラム自動認識完了（確信度 94%）     │
  │                                        │
  │ 元ファイル        → ウケトリ           │
  │ ─────────────────────────────────      │
  │ 顧客名     ✅     → 会社名            │
  │ メール     ✅     → メールアドレス      │
  │ 案件名     ✅     → 案件名            │
  │ 見積金額   ✅     → 合計金額           │
  │ 請求日     ✅     → 発行日            │
  │ 不明カラム  ⚠️    → [選択▼] [スキップ]│
  │                                        │
  │ [次へ: プレビュー確認]                 │
  └──────────────────────────────────────┘

Step 4: プレビュー＆実行
  ┌──────────────────────────────────────┐
  │ 取り込みプレビュー（先頭10件）          │
  │ | # | 会社名    | 案件名  | 金額     | │
  │ | 1 | A社       | Web制作 | ¥500,000 | │
  │ | 2 | B社       | 保守    | ¥50,000  | │
  │ ...                                    │
  │ ⚠️ 1件のエラー: 行5「金額が数値でない」│
  │                                        │
  │ 合計: 顧客48件 / 案件120件 / 帳票350件 │
  │ [移行を実行する]                       │
  └──────────────────────────────────────┘

Step 5: 完了
  ┌──────────────────────────────────────┐
  │ 🎉 移行完了！                          │
  │ 顧客: 48件 ✅ / 案件: 120件 ✅         │
  │ 帳票: 349件 ✅ / 1件スキップ           │
  │ 所要時間: 12秒                         │
  │                                        │
  │ [エラー詳細をダウンロード]              │
  │ [ダッシュボードへ →]                   │
  └──────────────────────────────────────┘
```

### 4.2.5 帳票作成・編集画面

**レイアウト:**
```
┌───────────────────────────────────────────────┐
│ ヘッダー: 「請求書を作成」 [下書き保存] [プレ  │
│ ビュー] [送信]                                │
├───────────────────┬───────────────────────────┤
│ 左パネル（入力）   │ 右パネル（リアルタイム     │
│                   │  PDFプレビュー）           │
│ 顧客: [選択▼]    │ ┌───────────────────────┐ │
│ 案件: [選択▼]    │ │  ┌─────────────────┐  │ │
│ 発行日: [____]    │ │  │ 株式会社サンプル │  │ │
│ 支払期日:[____]   │ │  │ T1234567890123  │  │ │
│                   │ │  │                 │  │ │
│ --- 明細行 ---    │ │  │ 御請求書        │  │ │
│ |品名|数量|単価|  │ │  │ A株式会社 御中  │  │ │
│ [+ 行追加]        │ │  │                 │  │ │
│ [AIで提案 🤖]     │ │  │ 品名  数量 金額 │  │ │
│                   │ │  │ ...            │  │ │
│ 小計: ¥500,000   │ │  │                 │  │ │
│ 消費税: ¥50,000  │ │  │ 合計 ¥550,000  │  │ │
│ 合計: ¥550,000   │ │  └─────────────────┘  │ │
│                   │ └───────────────────────┘ │
│ 備考: [________]  │                           │
│ 社内メモ:[_____]  │                           │
└───────────────────┴───────────────────────────┘
```

---

# 第5部：非機能要件

## 5.0 開発環境・技術スタック・デプロイ戦略

### 5.0.1 技術スタック

| レイヤー | 技術 | バージョン | 備考 |
|---------|------|-----------|------|
| フロントエンド | Next.js (App Router) | 15.x | TypeScript必須 |
| フロントエンド言語 | TypeScript | 5.x | strict mode有効。`any`禁止 |
| UIライブラリ | Tailwind CSS + shadcn/ui | — | |
| バックエンドAPI | Ruby on Rails (APIモード) | 7.2.x | |
| バックエンド言語 | Ruby | 3.3.x | YJIT有効 |
| データベース | PostgreSQL | 16.x | 開発:Docker / 本番:Supabase |
| ジョブキュー | SolidQueue | — | PostgreSQL-backed。Redis不要 |
| キャッシュ | SolidCache | — | PostgreSQL-backed。Redis不要 |
| テスト(API) | RSpec | — | |
| テスト(フロント) | Jest + React Testing Library | — | |
| E2Eテスト | Playwright | — | |
| リンター | RuboCop (Rails) / ESLint + Prettier (TS) | — | |

### 5.0.2 開発環境（Docker Compose）

開発環境はDocker Composeで統一し、チームメンバー（将来の増員含む）が `docker compose up` のみで開発開始できる状態を維持する。

```yaml
# docker-compose.yml
services:
  # --- バックエンド ---
  api:
    build:
      context: ./api
      dockerfile: Dockerfile.dev
    ports:
      - "3000:3000"
    volumes:
      - ./api:/app
      - api_bundle:/app/vendor/bundle
    environment:
      - DATABASE_URL=postgres://postgres:password@db:5432/uketori_development
      - RAILS_ENV=development
      - SOLID_QUEUE_IN_PUMA=true
      - R2_ACCESS_KEY_ID=minioadmin
      - R2_SECRET_ACCESS_KEY=minioadmin
      - R2_ENDPOINT=http://minio:9000
      - R2_BUCKET=uketori-dev
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
    depends_on:
      db:
        condition: service_healthy

  # --- フロントエンド ---
  web:
    build:
      context: ./web
      dockerfile: Dockerfile.dev
    ports:
      - "3001:3000"
    volumes:
      - ./web:/app
      - web_node_modules:/app/node_modules
    environment:
      - NEXT_PUBLIC_API_URL=http://localhost:3000

  # --- データベース ---
  db:
    image: postgres:16-alpine
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=uketori_development
    volumes:
      - pg_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  # --- S3互換ストレージ（R2の代替） ---
  minio:
    image: minio/minio
    ports:
      - "9000:9000"
      - "9001:9001"    # MinIO Console
    environment:
      - MINIO_ROOT_USER=minioadmin
      - MINIO_ROOT_PASSWORD=minioadmin
    volumes:
      - minio_data:/data
    command: server /data --console-address ":9001"

volumes:
  pg_data:
  api_bundle:
  web_node_modules:
  minio_data:
```

**開発環境のポイント:**

| 要素 | 開発環境 | 本番で何に相当するか |
|------|---------|-------------------|
| PostgreSQL | Docker (`postgres:16-alpine`) | Supabase PostgreSQL |
| S3互換ストレージ | MinIO (Docker) | Cloudflare R2 |
| Rails API | Docker (`Dockerfile.dev`) | AWS Lightsail（Docker + Nginx） |
| Next.js | Docker (`Dockerfile.dev`) | Vercel |
| Redis | **不要**（SolidQueue/SolidCacheのため） | **不要** |
| SolidQueue | Puma内蔵モード（api コンテナ内） | Puma内蔵モード（Lightsail） |

### 5.0.3 開発用Dockerfile

```dockerfile
# api/Dockerfile.dev
FROM ruby:3.3-slim

RUN apt-get update -qq && \
    apt-get install -y build-essential libpq-dev git curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

CMD ["bin/rails", "server", "-b", "0.0.0.0"]
```

```dockerfile
# web/Dockerfile.dev
FROM node:20-slim

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

CMD ["npm", "run", "dev"]
```

### 5.0.4 本番デプロイ構成（最安値）

| 環境 | 開発 | 本番（Phase 1） | 切替に必要な作業 |
|------|------|----------------|----------------|
| Rails API | Docker | **AWS Lightsail** (Micro-1GB $7/月) | Docker + Nginx構成 |
| Next.js | Docker | **Vercel** (¥0〜$20/月) | git push（自動デプロイ） |
| PostgreSQL | Docker postgres:16 | **Supabase** (¥0) | DATABASE_URL差替のみ |
| ファイルストレージ | MinIO (Docker) | **Cloudflare R2** (¥0) | endpoint/key差替のみ（S3互換） |
| DNS/SSL | — | **Cloudflare + Let's Encrypt** (¥0) | ドメイン設定 + certbot |
| メール | MailHog or letter_opener | **Resend** (¥0) | API key設定 |
| 監視 | — | **Sentry + BetterStack** (¥0) | DSN設定 |

**重要設計原則: 開発↔本番の差異は環境変数のみ**

```
開発: DATABASE_URL=postgres://postgres:password@db:5432/uketori_development
本番: DATABASE_URL=postgresql://postgres.[project-ref]:[password]@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres

開発: R2_ENDPOINT=http://minio:9000
本番: R2_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
```

ActiveStorage の S3 互換設定は開発・本番で同一。endpoint と認証情報を環境変数で切り替えるだけで動作する。

### 5.0.5 本番用Dockerfile（Lightsail / Docker用）

```dockerfile
# api/Dockerfile
FROM ruby:3.3-slim AS base
RUN apt-get update -qq && \
    apt-get install -y libpq-dev libjemalloc2 curl && \
    rm -rf /var/lib/apt/lists/*
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2
ENV RUBY_YJIT_ENABLE=1
ENV MALLOC_ARENA_MAX=2
WORKDIR /app

FROM base AS build
RUN apt-get update -qq && \
    apt-get install -y build-essential git && \
    rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test && \
    rm -rf ~/.bundle/ /usr/local/bundle/cache
COPY . .
RUN bundle exec bootsnap precompile --gemfile app/ lib/

FROM base
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app

EXPOSE 8080
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

### 5.0.6 CI/CDパイプライン

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_PASSWORD: password
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
          working-directory: api
      - run: bundle exec rspec
        working-directory: api
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
          cache-dependency-path: web/package-lock.json
      - run: npm ci && npm run lint && npm run type-check
        working-directory: web

  deploy-api:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Lightsail via SSH
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.LIGHTSAIL_HOST }}
          username: ubuntu
          key: ${{ secrets.LIGHTSAIL_SSH_KEY }}
          script: |
            cd /home/ubuntu/uketori
            git pull origin main
            docker compose -f docker-compose.production.yml build
            docker compose -f docker-compose.production.yml run --rm -e RAILS_ENV=production api bin/rails db:migrate
            docker compose -f docker-compose.production.yml up -d
            docker image prune -f

  # Vercelはgit push で自動デプロイのため、ジョブ不要
  # （Vercel GitHub Integration を有効化しておく）
```

### 5.0.7 リポジトリ構成

```
uketori/
├── api/                          # Rails API（バックエンド）
│   ├── Dockerfile                # 本番用（Lightsail Docker デプロイ）
│   ├── Dockerfile.dev            # 開発用（Docker Compose）
│   ├── Gemfile
│   ├── app/
│   ├── config/
│   │   ├── database.yml
│   │   ├── storage.yml           # R2/MinIO設定（S3互換）
│   │   ├── solid_queue.yml
│   │   ├── recurring.yml         # 定期ジョブスケジュール
│   │   └── puma.rb
│   ├── db/
│   │   └── migrate/
│   └── spec/
├── web/                          # Next.js フロントエンド
│   ├── Dockerfile.dev            # 開発用（Docker Compose）
│   ├── package.json
│   ├── tsconfig.json             # TypeScript strict mode
│   ├── next.config.ts
│   ├── vercel.json               # Vercel設定
│   ├── src/
│   │   ├── app/                  # App Router
│   │   ├── components/
│   │   ├── lib/
│   │   └── types/
│   └── __tests__/
├── docker-compose.yml            # 開発環境
├── .github/
│   └── workflows/
│       └── deploy.yml
└── README.md
```

## 5.1 パフォーマンス

| 項目 | 目標値 |
|------|--------|
| API応答時間（95パーセンタイル） | 200ms以下 |
| PDF生成時間 | 3秒以下 |
| AI消込処理（50件） | 15秒以下 |
| AI見積提案 | 5秒以下 |
| 移行処理（1000件） | 30秒以下 |
| ダッシュボード表示 | 1秒以下 |
| 同時接続ユーザー数 | 100（Phase 1）→ 1000（スケールアップ後） |

### Supabase接続時の考慮事項
- AWS Lightsail からは IPv4 前提になるため、`Session pooler`（ポート `5432`）の接続文字列を利用する
- Rails 本番設定では `prepared_statements: true` のため、`Transaction mode (6543)` ではなく `Session pooler` を使う
- `database.yml` に `connect_timeout: 10` を設定し、接続時の不安定さに備える
- 無料プランでも日次バックアップはあるが、運用上は `pg_dump` による自前バックアップを前提とする

## 5.2 セキュリティ

| 項目 | 実装 |
|------|------|
| 通信暗号化 | TLS 1.3（Cloudflare自動対応） |
| データ暗号化 | AES-256（テナントごとの暗号化キー） |
| パスワード | bcrypt (cost=12) |
| JWT有効期間 | アクセストークン15分、リフレッシュトークン7日 |
| CSRF対策 | APIモードのためトークンベース認証で対応 |
| XSS対策 | Content-Security-Policy ヘッダー設定 |
| SQLインジェクション | ActiveRecordのパラメータバインド |
| レートリミット | Rack::Attack（100req/min/user、ログイン5回/5min） |
| 2段階認証 | TOTP（Google Authenticator対応） |
| 監査ログ | 全CUD操作をaudit_logsに記録 |
| データ分離 | テナントIDによる行レベルセキュリティ |
| ファイルアクセス | R2署名付きURL（有効期限30分） |
| DDoS防御 | Cloudflare（無料プランに含まれる基本防御） |

## 5.3 可用性・インフラ

| 項目 | 仕様 |
|------|------|
| SLA目標 | Phase 1: 99.5% → Phase 2以降: 99.9% |
| バックアップ | Supabase日次バックアップ + cronによるpg_dump（日次・ローカル30日保持） |
| デプロイ | GitHub Actions → SSH → Docker Compose（Lightsail） |
| フロントデプロイ | GitHub Actions → Vercel（git push自動デプロイ） |
| 監視 | Sentry（エラー追跡）+ BetterStack（外形監視） |
| ログ | Docker json-file ログ（ローテーション設定済み）+ Sentry breadcrumbs |
| スケーリング | Phase 1: Lightsail プラン変更 → Phase 2: EC2/ECS移行 |

### インフラ構成詳細

| レイヤー | サービス | プラン | 費用 | 備考 |
|---------|---------|--------|------|------|
| DNS/SSL | Cloudflare + Let's Encrypt | Free | ¥0 | DNS管理 + 無料SSL証明書 |
| フロントエンド | Vercel | Hobby → Pro | ¥0 → $20 | Next.js SSR/SSG |
| APIサーバー | AWS Lightsail | Micro-1GB（1GB RAM, 2vCPU） | $7/月 | Docker + Nginx + Rails |
| データベース | Supabase PostgreSQL | Free → Pro | ¥0 → $25 | 東京リージョン対応。Freeは500MB |
| ファイルストレージ | Cloudflare R2 | Free | ¥0 | 10GB無料。S3互換API |
| メール送信 | Resend | Free → Pro | ¥0 → $20 | 月3,000通無料 |
| エラー監視 | Sentry | Free | ¥0 | 月5,000イベント |
| 外形監視 | BetterStack (旧Better Uptime) | Free | ¥0 | 5モニター無料 |
| CI/CD | GitHub Actions | Free | ¥0 | 月2,000分 |
| **合計（Phase 1）** | | | **約¥1,050/月 + Claude API従量課金** | |

### ジョブ基盤: SolidQueue

Sidekiq + Redis を SolidQueue で完全置換。PostgreSQLのみで非同期ジョブを実現する。

```ruby
# Gemfile
gem 'solid_queue'   # 非同期ジョブキュー（PostgreSQL-backed）
gem 'solid_cache'   # Rails.cache（PostgreSQL-backed）
# gem 'solid_cable' # ActionCable用（Phase 2以降で必要になった場合）

# Sidekiq / Redis は使用しない
```

**SolidQueue設定:**
```yaml
# config/solid_queue.yml
production:
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3         # Lightsail 1GBに合わせてスレッド数を制限
      processes: 1
      polling_interval: 0.1
```

**SolidQueue実行モード（Phase別）:**

| Phase | 実行モード | 説明 |
|-------|-----------|------|
| Phase 1 (0〜100ユーザー) | **in-process（puma内蔵）** | Railsプロセス内でワーカーを実行。別プロセス不要でコスト最小 |
| Phase 2 (100〜500ユーザー) | **separate process** | `bin/jobs` で別プロセス起動。Lightsailプラン拡張 |
| Phase 3 (500+) | **multi-process** | EC2/ECS移行。複数ワーカープロセス |

```ruby
# config/puma.rb（Phase 1: in-process mode）
plugin :solid_queue if ENV.fetch("SOLID_QUEUE_IN_PUMA", "true") == "true"
```

### キャッシュ基盤: SolidCache

```ruby
# config/environments/production.rb
config.cache_store = :solid_cache_store

# ※ 初期フェーズではキャッシュなし運用も可。
# ユーザーが少ないうちはDB直接クエリで十分なパフォーマンス。
```

### ファイルストレージ: Cloudflare R2

```yaml
# config/storage.yml
cloudflare_r2:
  service: S3                  # S3互換のためそのまま利用可能
  endpoint: https://<ACCOUNT_ID>.r2.cloudflarestorage.com
  access_key_id: <%= ENV['R2_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['R2_SECRET_ACCESS_KEY'] %>
  bucket: uketori-production
  region: auto
```

```ruby
# config/environments/production.rb
config.active_storage.service = :cloudflare_r2
```

### Docker メモリ最適化（Lightsail用）

```dockerfile
# Dockerfile
ENV RUBY_YJIT_ENABLE=1
ENV MALLOC_ARENA_MAX=2
ENV RUBY_GC_HEAP_INIT_SLOTS=100000
ENV RUBY_GC_HEAP_FREE_SLOTS=500000

# jemalloc でメモリフラグメンテーション防止
RUN apt-get install -y libjemalloc2
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2
```

## 5.4 テスト方針

| テスト種別 | ツール | カバレッジ目標 |
|-----------|--------|-------------|
| モデル単体テスト | RSpec | 90%以上 |
| APIリクエストテスト | RSpec (request spec) | 全エンドポイント |
| サービスオブジェクトテスト | RSpec | 90%以上 |
| フロントエンド単体テスト | Jest + React Testing Library | 主要コンポーネント |
| E2Eテスト | Playwright | 主要ユーザーフロー10本 |
| 負荷テスト | k6 | リリース前に実施 |

---

# 第6部：開発ロードマップ

## Phase 1: MVP（12週間）— 入金回収特化 + 移行爆速の核心を含む

| 週 | 開発内容 | 完了条件 |
|----|---------|---------|
| 1 | 環境構築・DB設計・API設計 | Rails + Next.js + Supabase PostgreSQL + Cloudflare R2 が起動。全テーブルのマイグレーション完了。SolidQueue動作確認 |
| 2 | 認証・テナント・ユーザー管理 | 管理者発行アカウントでログイン→JWT発行→認可が動作 |
| 3 | 自社情報設定・業種テンプレート | テナント設定画面。業種選択で用語・品目が切り替わる |
| 4 | 顧客マスタ管理（CRUD + 適格番号検証） | 顧客一覧・作成・編集・削除。国税庁API連携 |
| 5 | 品目マスタ + 見積書作成・編集 | 見積書の明細入力。金額自動計算（税率別集計） |
| 6 | 見積書PDF生成・メール送信 | インボイス対応PDFの生成。メール送信 |
| 7 | 請求書作成（見積→請求変換含む） | 見積書から請求書への変換。請求書固有項目（支払期日等） |
| 8 | 請求書PDF・送信 + 入金管理（手動消込） | 請求書送信。入金登録→消込→ステータス更新 |
| 9 | **★銀行明細CSV取込 + AI入金消込** | CSV取込→AI自動マッチング→確認UI→消込確定 |
| 10 | **★督促管理（自動リマインド）+ 回収ダッシュボード** | 督促ルール設定→自動メール送信。売掛金年齢表 |
| 11 | **★データ移行ウィザード（board + Excel対応）** | ファイルアップロード→AI自動マッピング→プレビュー→取込完了 |
| 12 | ダッシュボード + テスト + バグ修正 | メインダッシュボード。主要フローのE2Eテスト通過 |

**MVP完了時の機能:**
- ✅ 顧客管理（適格番号検証付き）
- ✅ 見積書・請求書の作成・PDF・送信（インボイス対応）
- ✅ 入金管理（手動消込 + **AI自動消込**）★
- ✅ **自動督促（メールリマインド）** ★
- ✅ **回収ダッシュボード（売掛金年齢表・与信スコア）** ★
- ✅ **データ移行ウィザード（board + Excel）** ★
- ✅ 電子帳簿保存法対応（基本）
- ✅ ダッシュボード

## Phase 2: 機能拡充（8週間）

| 週 | 開発内容 |
|----|---------|
| 13-14 | 案件管理・パイプライン（カンバン） |
| 15-16 | 受発注管理（発注書・納品書・注文請書・領収書） |
| 17-18 | 定期請求・一括請求 + 会計ソフト連携CSV出力 |
| 19-20 | 移行対応拡充（freee, Misoca, MakeLeaps） + AI見積提案 |

## Phase 3: 高度化（8週間）

| 週 | 開発内容 |
|----|---------|
| 21-22 | AI売上予測・AI書類OCR |
| 23-24 | 権限管理強化・操作ログ・承認フロー |
| 25-26 | レポート充実 + 追加業種テンプレート |
| 27-28 | パフォーマンス最適化・セキュリティ強化・Stripe課金実装 |

---

# 第7部：SolidQueueジョブ定義

> ※ v1.0ではSidekiq + Redisを使用していたが、v1.1でSolidQueue（PostgreSQL-backed）に完全移行。
> ジョブの定義・インターフェースはActiveJobに準拠しており、実装コードの変更は不要。

| ジョブ名 | トリガー | キュー | 処理内容 |
|---------|---------|--------|---------|
| InvoiceOverdueCheckJob | 毎日9:00（recurring） | default | 支払期日超過の請求書を検出→payment_status='overdue'に更新→通知作成 |
| DunningExecutionJob | 毎日10:00（recurring） | default | 督促ルールに基づきメール送信→dunning_logs記録 |
| CreditScoreCalculationJob | 毎日深夜2:00（recurring） | default | 全顧客の与信スコアを再計算→credit_score_histories記録 |
| RecurringInvoiceGenerationJob | 毎日6:00（recurring） | default | 定期請求ルールに基づき請求書を自動生成 |
| InvoiceNumberVerificationJob | 非同期（顧客作成時） | default | 国税庁APIで適格番号を検証 |
| PdfGenerationJob | 非同期（帳票確定時） | default | PDF生成→R2アップロード→pdf_url更新 |
| ImportExecutionJob | 非同期（移行実行時） | default | CSVパース→マッピング適用→DBインサート→結果記録 |
| AiBankMatchJob | 非同期（CSV取込時） | default | 銀行明細に対してAI消込を実行 |
| CustomerStatsUpdateJob | 毎日深夜3:00（recurring） | default | avg_payment_days, late_payment_rate, total_outstandingを再計算 |
| MonthlyReportGenerationJob | 毎月1日8:00（recurring） | default | 月次レポートPDFを生成→通知 |

### SolidQueueの定期実行設定

```yaml
# config/recurring.yml
production:
  invoice_overdue_check:
    class: InvoiceOverdueCheckJob
    schedule: every day at 9:00 Asia/Tokyo
  dunning_execution:
    class: DunningExecutionJob
    schedule: every day at 10:00 Asia/Tokyo
  credit_score_calculation:
    class: CreditScoreCalculationJob
    schedule: every day at 2:00 Asia/Tokyo
  recurring_invoice_generation:
    class: RecurringInvoiceGenerationJob
    schedule: every day at 6:00 Asia/Tokyo
  customer_stats_update:
    class: CustomerStatsUpdateJob
    schedule: every day at 3:00 Asia/Tokyo
  monthly_report:
    class: MonthlyReportGenerationJob
    schedule: every month on the 1st at 8:00 Asia/Tokyo
```

---

# 第8部：料金プランとプラン制限の実装

## 8.1 プラン定義

| プラン | 月額 | ユーザー数 | 帳票作成 | 顧客数 | AI消込 | 自動督促 | 移行 |
|--------|------|-----------|---------|--------|--------|---------|------|
| free | ¥0 | 1 | 月5件 | 10社 | ❌ | ❌ | 1回のみ |
| starter | ¥2,980 | 3 | 月50件 | 100社 | ✅ | ✅(基本) | 無制限 |
| standard | ¥4,980 | 10 | 無制限 | 500社 | ✅ | ✅(全機能) | 無制限 |
| professional | ¥9,800 | 30 | 無制限 | 無制限 | ✅ | ✅(全機能) | 無制限 |

## 8.2 プラン制限チェック実装

```ruby
# app/services/plan_limit_checker.rb
class PlanLimitChecker
  LIMITS = {
    free:         { users: 1,  documents_monthly: 5,  customers: 10,  ai_match: false, dunning: false },
    starter:      { users: 3,  documents_monthly: 50, customers: 100, ai_match: true,  dunning: :basic },
    standard:     { users: 10, documents_monthly: nil, customers: 500, ai_match: true,  dunning: :full },
    professional: { users: 30, documents_monthly: nil, customers: nil, ai_match: true,  dunning: :full }
  }.freeze

  def initialize(tenant)
    @tenant = tenant
    @limits = LIMITS[@tenant.plan.to_sym]
  end

  def can_create_document?
    return true if @limits[:documents_monthly].nil?
    current_month_count = @tenant.documents
      .where(created_at: Time.current.beginning_of_month..Time.current.end_of_month)
      .count
    current_month_count < @limits[:documents_monthly]
  end

  def can_add_customer?
    return true if @limits[:customers].nil?
    @tenant.customers.where(deleted_at: nil).count < @limits[:customers]
  end

  def can_add_user?
    @tenant.users.where(deleted_at: nil).count < @limits[:users]
  end

  def can_use_ai_match?
    @limits[:ai_match]
  end

  def can_use_dunning?(level = :basic)
    return false unless @limits[:dunning]
    return true if @limits[:dunning] == :full
    level == :basic
  end
end
```

---

# 第9部：外部連携仕様

## 9.1 国税庁 適格請求書発行事業者公表API

| 項目 | 値 |
|------|-----|
| URL | `https://web-api.invoice-kohyo.nta.go.jp/1/num?id={T+13桁}` |
| メソッド | GET |
| 認証 | アプリケーションID（事前登録） |
| レート制限 | 1回/秒 |
| 用途 | 取引先の適格請求書番号の有効性検証 |

## 9.2 Claude API（AI機能）

| 用途 | モデル | 最大トークン | 備考 |
|------|--------|------------|------|
| AI見積提案 | claude-sonnet-4-20250514 | 2000 | 過去見積データをコンテキストに含める |
| AI入金消込 | claude-haiku-4-5-20251001 | 1000 | ルールベースで絞り込み後のみAIに渡す。**コスト最適化のためHaiku使用** |
| AI売上予測 | claude-haiku-4-5-20251001 | 1500 | 数値予測は統計モデル、コメントをAI生成。**Haiku使用** |
| AI書類OCR | claude-sonnet-4-20250514 | 2000 | Vision APIで画像/PDFから情報抽出 |
| AI移行マッピング | claude-haiku-4-5-20251001 | 1000 | ヘッダー行のみ送信（データは送らない）。**Haiku使用** |

### Claude APIコスト最適化方針

| 方針 | 詳細 |
|------|------|
| モデル使い分け | 高精度が必要な見積提案・OCRはSonnet、パターンマッチ寄りの消込・予測・マッピングはHaiku |
| ルールベース優先 | AI呼び出し前にルールベースで解決できるものは呼ばない（消込のconfidence >= 0.7はAI不要） |
| トークン最小化 | プロンプトに含めるデータを最小限に絞る。候補を事前フィルタリング |
| バッチ処理 | 複数の消込候補を1回のAPI呼び出しでまとめて処理 |

## 9.3 会計ソフト連携CSV出力フォーマット

| 会計ソフト | 出力形式 | 対応カラム |
|-----------|---------|-----------|
| freee | freee仕訳インポートCSV | 取引日, 借方勘定科目, 借方金額, 貸方勘定科目, 貸方金額, 摘要, 税区分 |
| マネーフォワード | MFクラウド仕訳CSV | 取引日, 借方勘定科目, 借方補助科目, 借方金額, 貸方勘定科目, 貸方補助科目, 貸方金額, 摘要 |
| 弥生会計 | 弥生インポート形式 | 伝票日付, 借方勘定科目, 借方金額, 貸方勘定科目, 貸方金額, 摘要 |

---

# 第10部：IT導入補助金対応要件

## 10.1 該当プロセス

| コード | プロセス名 | 対応機能 |
|--------|-----------|---------|
| 共P-01 | 顧客対応・販売支援 | 顧客管理、案件管理（パイプライン） |
| 共P-02 | 決済・債権債務・資金回収 | 見積・請求・入金管理・督促・回収管理 |

## 10.2 加点要素

| 加点項目 | 該当 | 根拠 |
|---------|------|------|
| クラウド（SaaS） | ✅ | Webブラウザアクセス。データはクラウド上（Supabase + Cloudflare R2） |
| インボイス制度対応 | ✅ | 適格請求書発行。登録番号自動検証 |
| 電子帳簿保存法対応 | ✅ | タイムスタンプ・検索・改ざん防止 |
| AI機能搭載 | ✅ | AI消込・AI見積提案・AI売上予測・AI OCR・AIマッピング |

## 10.3 登録審査で求められる資料

| 資料 | 準備方法 |
|------|---------|
| 機能一覧書 | 本要件定義書のSection3-4をベースに作成 |
| 操作マニュアル | 画面キャプチャ付きPDF（Notionで作成→PDF出力） |
| セキュリティポリシー | SECURITY ACTIONの宣言 + 本書Section5.2をベースに作成 |
| 販売実績 | 3-5社への有償販売の証跡（請求書・入金記録） |
| 利用規約・プライバシーポリシー | 弁護士レビュー済みの文書 |
| サポート体制の説明 | メール・チャットサポートの運用体制説明 |

---

# 付録A: 環境変数一覧

```bash
# Rails
RAILS_ENV=production
SECRET_KEY_BASE=xxx
DATABASE_URL=postgresql://postgres.[project-ref]:[password]@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres
# ※ Supabase Session pooler接続URL（AWS Lightsail向け）

# SolidQueue
SOLID_QUEUE_IN_PUMA=true          # Phase 1: Puma内蔵モード
# SOLID_QUEUE_IN_PUMA=false       # Phase 2以降: 別プロセス

# JWT
JWT_SECRET=xxx
JWT_EXPIRATION=900                 # 15分
JWT_REFRESH_EXPIRATION=604800      # 7日

# Cloudflare R2（S3互換）
R2_ACCESS_KEY_ID=xxx
R2_SECRET_ACCESS_KEY=xxx
R2_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
R2_BUCKET=uketori-production

# AI
ANTHROPIC_API_KEY=xxx

# メール（Resend SMTP）
RESEND_API_KEY=xxx
MAILER_FROM=noreply@uketori.jp

# Stripe
STRIPE_SECRET_KEY=xxx
STRIPE_WEBHOOK_SECRET=xxx
STRIPE_STARTER_PRICE_ID=price_xxx
STRIPE_STANDARD_PRICE_ID=price_xxx
STRIPE_PROFESSIONAL_PRICE_ID=price_xxx

# 国税庁API
NTA_APP_ID=xxx

# Sentry
SENTRY_DSN=xxx

# AWS Lightsail
# PORT=8080（docker-compose.production.yml で設定）
```

# 付録B: 初期データ（Seeds）

## 業種テンプレート

```ruby
IndustryTemplate.create!([
  {
    code: 'general',
    name: '汎用（全業種共通）',
    labels: { project: '案件', document: '帳票' },
    default_products: [
      { name: '作業費', unit: '式', tax_rate_type: 'standard' },
      { name: '消耗品', unit: '個', tax_rate_type: 'standard' }
    ]
  },
  {
    code: 'it',
    name: 'IT・Web制作業',
    labels: { project: 'プロジェクト', document: '帳票' },
    default_products: [
      { name: 'システム設計', unit: '人月', tax_rate_type: 'standard' },
      { name: 'プログラミング', unit: '時間', tax_rate_type: 'standard' },
      { name: 'デザイン制作', unit: '式', tax_rate_type: 'standard' },
      { name: 'サーバー費用', unit: '月', tax_rate_type: 'standard' },
      { name: '保守・運用', unit: '月', tax_rate_type: 'standard' }
    ]
  },
  {
    code: 'construction',
    name: '建設業',
    labels: { project: '工事案件', document: '帳票' },
    default_products: [
      { name: '材料費', unit: '式', tax_rate_type: 'standard' },
      { name: '労務費', unit: '人工', tax_rate_type: 'standard' },
      { name: '外注費', unit: '式', tax_rate_type: 'standard' },
      { name: '諸経費', unit: '式', tax_rate_type: 'standard' }
    ]
  },
  {
    code: 'design',
    name: 'デザイン・クリエイティブ業',
    labels: { project: '案件', document: '帳票' },
    default_products: [
      { name: 'デザイン制作費', unit: '式', tax_rate_type: 'standard' },
      { name: '撮影費', unit: '回', tax_rate_type: 'standard' },
      { name: '印刷費', unit: '部', tax_rate_type: 'standard' },
      { name: 'ディレクション費', unit: '式', tax_rate_type: 'standard' }
    ]
  },
  {
    code: 'consulting',
    name: 'コンサルティング業',
    labels: { project: 'プロジェクト', document: '帳票' },
    default_products: [
      { name: 'コンサルティング費', unit: '時間', tax_rate_type: 'standard' },
      { name: '顧問料', unit: '月', tax_rate_type: 'standard' },
      { name: '調査・分析費', unit: '式', tax_rate_type: 'standard' }
    ]
  },
  {
    code: 'legal',
    name: '士業（税理士・社労士等）',
    labels: { project: '顧問契約', document: '帳票' },
    default_products: [
      { name: '顧問報酬', unit: '月', tax_rate_type: 'standard' },
      { name: '決算申告報酬', unit: '式', tax_rate_type: 'standard' },
      { name: '年末調整報酬', unit: '式', tax_rate_type: 'standard' },
      { name: 'スポット相談', unit: '時間', tax_rate_type: 'standard' }
    ]
  }
])
```

## デフォルト督促ルール

```ruby
# テナント作成時に自動生成（dunning_enabled=true設定時）
DunningRule.create!([
  {
    name: 'やさしいリマインド',
    trigger_days_after_due: 1,
    action_type: 'email',
    email_template_subject: '【{{company_name}}】お支払いのご確認（{{document_number}}）',
    email_template_body: <<~BODY,
      {{customer_name}} 御中

      いつもお世話になっております。{{company_name}}です。

      下記請求書のお支払い期日が過ぎておりますので、ご確認をお願いいたします。

      請求書番号: {{document_number}}
      請求金額: {{total_amount}}円
      お支払い期日: {{due_date}}
      未入金額: {{remaining_amount}}円

      既にお振込み済みの場合は、本メールをご容赦ください。

      ■お振込先
      {{bank_info}}

      何かご不明な点がございましたら、お気軽にお問い合わせください。
    BODY
    sort_order: 1,
    max_dunning_count: 1,
    interval_days: 0
  },
  {
    name: '通常督促',
    trigger_days_after_due: 7,
    action_type: 'both',
    email_template_subject: '【再送】【{{company_name}}】お支払いのお願い（{{document_number}}）',
    email_template_body: <<~BODY,
      {{customer_name}} 御中

      平素よりお世話になっております。{{company_name}}です。

      先日ご連絡いたしました下記請求書について、現時点でご入金の確認が取れておりません。
      お忙しいところ恐れ入りますが、お支払いのお手続きをお願い申し上げます。

      請求書番号: {{document_number}}
      請求金額: {{total_amount}}円
      お支払い期日: {{due_date}}（{{overdue_days}}日超過）
      未入金額: {{remaining_amount}}円

      ■お振込先
      {{bank_info}}
    BODY
    sort_order: 2,
    max_dunning_count: 2,
    interval_days: 7
  },
  {
    name: '強い督促',
    trigger_days_after_due: 21,
    action_type: 'both',
    email_template_subject: '【重要】【{{company_name}}】お支払いについてのお願い（{{document_number}}）',
    sort_order: 3,
    max_dunning_count: 2,
    interval_days: 7
  },
  {
    name: '最終通知',
    trigger_days_after_due: 45,
    action_type: 'both',
    email_template_subject: '【最終のご連絡】【{{company_name}}】未払い請求書について（{{document_number}}）',
    sort_order: 4,
    max_dunning_count: 1,
    interval_days: 0
  }
])
```

---

# 付録C: v1.0 → v1.1 変更差分サマリー

| 項目 | v1.0 | v1.1 → v1.2 | 影響範囲 |
|------|------|------|---------|
| ジョブキュー | Sidekiq + Redis | **SolidQueue（PostgreSQL-backed）** | Gemfile, config, デプロイ |
| キャッシュ | Redis | **SolidCache（PostgreSQL-backed）** | Gemfile, config |
| データベース | RDS PostgreSQL | **Supabase PostgreSQL** | DATABASE_URL, 接続設定 |
| ファイルストレージ | AWS S3 | **Cloudflare R2（S3互換）** | storage.yml, 環境変数 |
| CDN/SSL | CloudFront + ACM | **Cloudflare DNS + Let's Encrypt** | DNS設定, certbot |
| APIサーバー | ECS Fargate | **AWS Lightsail（Docker + Nginx）** | Dockerfile, docker-compose, Nginx |
| フロントエンド | ECS Fargate | **Vercel** | vercel.json, デプロイ |
| デプロイ | ECR → ECS Blue/Green | **GitHub Actions → SSH → Docker Compose** | CI/CDパイプライン |
| 監視 | CloudWatch + Sentry | **Sentry + BetterStack** | 監視設定 |
| メール | SendGrid | **Resend（SMTP）** | メール設定 |
| 月額コスト | ¥15,000〜40,000 | **¥0〜1,500（3ヶ月無料）** | — |
| AI消込モデル | Claude Sonnet（全タスク） | **タスク別にSonnet/Haiku使い分け** | API呼び出し設定 |
| SLA目標 | 99.9% | **Phase 1: 99.5% → Phase 2: 99.9%** | 運用設計 |
