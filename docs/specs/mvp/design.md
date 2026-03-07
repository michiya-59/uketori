# ウケトリ MVP 設計書

> **Phase:** Design Documentation
> **Scope:** MVP Phase 1（12週間 - 全機能）
> **作成日:** 2026-02-27

---

## 1. Overview

ウケトリは中小企業・フリーランス向けのAI搭載 受発注・請求・入金回収管理SaaS。
フロントエンド（Next.js 15 App Router）とバックエンドAPI（Rails 7.2 APIモード）の分離アーキテクチャ。
Docker Compose で開発環境を統一し、本番は Vercel + Fly.io + Neon + Cloudflare R2 の極限コスト構成。

### 差別化の核心
1. **入金回収特化:** AI入金消込・自動督促・回収率ダッシュボード・与信スコアリング
2. **移行爆速:** AI自動カラムマッピングによるデータ移行ウィザード

---

## 2. Architecture

### 2.1 システム全体構成

```
┌─────────────────────────────────────────────────────────┐
│                     Browser (User)                       │
└──────────────────────┬──────────────────────────────────┘
                       │ HTTPS
┌──────────────────────▼──────────────────────────────────┐
│              Cloudflare (DNS + CDN + SSL)                │
└──────────┬───────────────────────┬──────────────────────┘
           │                       │
┌──────────▼──────────┐ ┌─────────▼──────────────────────┐
│ Vercel / Docker      │ │ Fly.io / Docker                 │
│ (Next.js 15)         │ │ (Rails 7.2 API mode)            │
│ - App Router (SSR)   │ │ - JWT Auth (devise-jwt)         │
│ - Tailwind + shadcn  │ │ - Pundit (Authorization)        │
│ - TypeScript strict  │ │ - ActiveStorage (→ R2/MinIO)    │
│ Port: 3001 (dev)     │ │ - SolidQueue (in-process)       │
└─────────────────────┘ │ - SolidCache                     │
                        │ Port: 3000 (dev)                  │
                        └────┬──────────┬─────────────────┘
                             │          │
              ┌──────────────┼──────────┼──────────────┐
              │              │          │              │
       ┌──────▼──┐   ┌──────▼──┐ ┌────▼─────┐ ┌─────▼───────┐
       │PostgreSQL│   │R2/MinIO │ │Cloudflare│ │External APIs│
       │ 16      │   │(Files)  │ │(CDN/DNS) │ │- Claude API │
       │+Solid   │   │         │ │          │ │- 国税庁API  │
       │ Queue   │   │         │ │          │ │- SendGrid   │
       │ Cache   │   │         │ │          │ │- Stripe     │
       └─────────┘   └─────────┘ └──────────┘ └─────────────┘
```

### 2.2 開発環境（Docker Compose）

| Service | Image/Build | Port | Purpose |
|---------|------------|------|---------|
| api | ./api/Dockerfile.dev (ruby:3.3-slim) | 3000 | Rails API + SolidQueue |
| web | ./web/Dockerfile.dev (node:20-slim) | 3001 | Next.js dev server |
| db | postgres:16-alpine | 5432 | PostgreSQL |
| minio | minio/minio | 9000/9001 | S3互換ストレージ |

### 2.3 ディレクトリ構成

```
uketori/
├── api/                              # Rails API
│   ├── Dockerfile                    # 本番用
│   ├── Dockerfile.dev                # 開発用
│   ├── Gemfile
│   ├── app/
│   │   ├── controllers/
│   │   │   ├── application_controller.rb
│   │   │   └── api/
│   │   │       └── v1/
│   │   │           ├── auth_controller.rb
│   │   │           ├── customers_controller.rb
│   │   │           ├── projects_controller.rb
│   │   │           ├── documents_controller.rb
│   │   │           ├── payments_controller.rb
│   │   │           ├── bank_statements_controller.rb
│   │   │           ├── dunning/
│   │   │           │   ├── rules_controller.rb
│   │   │           │   └── logs_controller.rb
│   │   │           ├── collection_controller.rb
│   │   │           ├── imports_controller.rb
│   │   │           ├── products_controller.rb
│   │   │           ├── notifications_controller.rb
│   │   │           ├── tenants_controller.rb
│   │   │           ├── users_controller.rb
│   │   │           └── dashboard_controller.rb
│   │   ├── models/
│   │   │   ├── tenant.rb
│   │   │   ├── user.rb
│   │   │   ├── customer.rb
│   │   │   ├── customer_contact.rb
│   │   │   ├── product.rb
│   │   │   ├── project.rb
│   │   │   ├── document.rb
│   │   │   ├── document_item.rb
│   │   │   ├── document_version.rb
│   │   │   ├── recurring_rule.rb
│   │   │   ├── payment_record.rb
│   │   │   ├── bank_statement.rb
│   │   │   ├── dunning_rule.rb
│   │   │   ├── dunning_log.rb
│   │   │   ├── credit_score_history.rb
│   │   │   ├── import_job.rb
│   │   │   ├── import_column_definition.rb
│   │   │   ├── industry_template.rb
│   │   │   ├── notification.rb
│   │   │   └── audit_log.rb
│   │   ├── services/
│   │   │   ├── plan_limit_checker.rb
│   │   │   ├── document_calculator.rb
│   │   │   ├── document_number_generator.rb
│   │   │   ├── document_converter.rb
│   │   │   ├── pdf_generator.rb
│   │   │   ├── bank_statement_importer.rb
│   │   │   ├── ai_bank_matcher.rb
│   │   │   ├── dunning_executor.rb
│   │   │   ├── credit_score_calculator.rb
│   │   │   ├── import_executor.rb
│   │   │   ├── ai_column_mapper.rb
│   │   │   ├── invoice_number_verifier.rb
│   │   │   ├── jwt_service.rb
│   │   │   └── audit_logger.rb
│   │   ├── jobs/
│   │   │   ├── invoice_overdue_check_job.rb
│   │   │   ├── dunning_execution_job.rb
│   │   │   ├── credit_score_calculation_job.rb
│   │   │   ├── recurring_invoice_generation_job.rb
│   │   │   ├── invoice_number_verification_job.rb
│   │   │   ├── pdf_generation_job.rb
│   │   │   ├── import_execution_job.rb
│   │   │   ├── ai_bank_match_job.rb
│   │   │   ├── customer_stats_update_job.rb
│   │   │   └── monthly_report_generation_job.rb
│   │   ├── policies/                 # Pundit policies
│   │   │   ├── application_policy.rb
│   │   │   ├── customer_policy.rb
│   │   │   ├── project_policy.rb
│   │   │   ├── document_policy.rb
│   │   │   ├── payment_record_policy.rb
│   │   │   └── ...
│   │   ├── serializers/              # JSON serializers
│   │   │   ├── customer_serializer.rb
│   │   │   ├── document_serializer.rb
│   │   │   └── ...
│   │   └── mailers/
│   │       ├── document_mailer.rb
│   │       ├── dunning_mailer.rb
│   │       ├── invitation_mailer.rb
│   │       └── password_reset_mailer.rb
│   ├── config/
│   │   ├── database.yml
│   │   ├── storage.yml
│   │   ├── solid_queue.yml
│   │   ├── solid_cache.yml
│   │   ├── recurring.yml
│   │   ├── puma.rb
│   │   ├── routes.rb
│   │   └── initializers/
│   │       ├── cors.rb
│   │       ├── jwt.rb
│   │       ├── rack_attack.rb
│   │       └── solid_queue.rb
│   ├── db/
│   │   ├── migrate/
│   │   └── seeds.rb
│   └── spec/
│       ├── models/
│       ├── requests/
│       ├── services/
│       ├── jobs/
│       └── factories/
├── web/                              # Next.js Frontend
│   ├── Dockerfile.dev
│   ├── package.json
│   ├── tsconfig.json
│   ├── next.config.ts
│   ├── tailwind.config.ts
│   ├── src/
│   │   ├── app/
│   │   │   ├── layout.tsx
│   │   │   ├── page.tsx
│   │   │   ├── (auth)/
│   │   │   │   ├── login/page.tsx
│   │   │   │   ├── signup/page.tsx
│   │   │   │   └── password/reset/page.tsx
│   │   │   └── (dashboard)/
│   │   │       ├── layout.tsx            # サイドバー付きレイアウト
│   │   │       ├── dashboard/page.tsx
│   │   │       ├── collection/
│   │   │       │   ├── page.tsx          # 回収ダッシュボード
│   │   │       │   └── aging/page.tsx    # 売掛金年齢表
│   │   │       ├── customers/
│   │   │       │   ├── page.tsx
│   │   │       │   ├── [uuid]/page.tsx
│   │   │       │   └── [uuid]/edit/page.tsx
│   │   │       ├── projects/
│   │   │       │   ├── page.tsx
│   │   │       │   ├── [uuid]/page.tsx
│   │   │       │   └── [uuid]/edit/page.tsx
│   │   │       ├── documents/
│   │   │       │   ├── page.tsx
│   │   │       │   ├── [uuid]/page.tsx
│   │   │       │   ├── [uuid]/edit/page.tsx
│   │   │       │   └── [uuid]/preview/page.tsx
│   │   │       ├── payments/
│   │   │       │   ├── page.tsx
│   │   │       │   └── bank-import/page.tsx
│   │   │       ├── dunning/page.tsx
│   │   │       ├── import/page.tsx
│   │   │       ├── reports/page.tsx
│   │   │       ├── settings/
│   │   │       │   ├── company/page.tsx
│   │   │       │   ├── users/page.tsx
│   │   │       │   ├── industry/page.tsx
│   │   │       │   ├── dunning/page.tsx
│   │   │       │   ├── notifications/page.tsx
│   │   │       │   └── billing/page.tsx
│   │   │       └── notifications/page.tsx
│   │   ├── components/
│   │   │   ├── ui/                   # shadcn/ui components
│   │   │   ├── layout/
│   │   │   │   ├── sidebar.tsx
│   │   │   │   ├── header.tsx
│   │   │   │   └── breadcrumb.tsx
│   │   │   ├── auth/
│   │   │   ├── customers/
│   │   │   ├── documents/
│   │   │   ├── payments/
│   │   │   ├── collection/
│   │   │   ├── import/
│   │   │   └── dashboard/
│   │   ├── lib/
│   │   │   ├── api-client.ts         # API通信ラッパー
│   │   │   ├── auth.ts               # JWT管理
│   │   │   ├── utils.ts
│   │   │   └── validations.ts
│   │   ├── hooks/
│   │   │   ├── use-auth.ts
│   │   │   ├── use-api.ts
│   │   │   └── use-toast.ts
│   │   └── types/
│   │       ├── tenant.ts
│   │       ├── user.ts
│   │       ├── customer.ts
│   │       ├── project.ts
│   │       ├── document.ts
│   │       ├── payment.ts
│   │       ├── bank-statement.ts
│   │       ├── dunning.ts
│   │       ├── import.ts
│   │       └── api.ts
│   └── __tests__/
├── docker-compose.yml
├── .github/workflows/deploy.yml
├── .env.example
└── CLAUDE.md
```

---

## 3. Components and Interfaces

### 3.1 バックエンド: Rails API

#### 3.1.1 ApplicationController（基盤）

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include Pundit::Authorization

  before_action :authenticate_user!
  before_action :set_current_tenant

  # @return [User] 現在のユーザー
  attr_reader :current_user

  # @return [Tenant] 現在のテナント
  attr_reader :current_tenant

  private

  # JWT認証: Authorizationヘッダーからトークンを検証
  def authenticate_user!
    # JwtService.decode(token) → user_id, tenant_id を取得
    # User.find(user_id) で current_user を設定
  end

  # テナントスコープ: 全クエリにtenant_idを自動適用
  def set_current_tenant
    @current_tenant = current_user.tenant
    Current.tenant = @current_tenant  # ActiveSupport::CurrentAttributes
  end

  # Pundit認可エラーハンドリング
  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
end
```

#### 3.1.2 テナントスコープ（マルチテナント分離）

```ruby
# app/models/concerns/tenant_scoped.rb
module TenantScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :tenant
    default_scope { where(tenant_id: Current.tenant&.id) if Current.tenant }
  end
end
```

#### 3.1.3 API共通仕様

| 項目 | 仕様 |
|------|------|
| ベースパス | `/api/v1` |
| 認証 | `Authorization: Bearer {JWT}` |
| レスポンス形式 | JSON |
| ページネーション | `?page=1&per_page=25` (最大100) |
| ソート | `?sort=created_at&order=desc` |
| フィルタ | `?filter[status]=overdue&filter[customer_id]=123` |
| エラー形式 | `{"error":{"code":"...","message":"...","details":[...]}}` |

#### 3.1.4 ルーティング設計

```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # 認証
      namespace :auth do
        post 'sign_up'
        post 'sign_in'
        post 'refresh'
        delete 'sign_out'
        post 'password/reset'
        patch 'password/update'
        post 'invitation/accept'
      end

      # テナント設定
      resource :tenant, only: [:show, :update]

      # ユーザー管理
      resources :users, only: [:index, :create, :show, :update, :destroy] do
        post :invite, on: :collection
      end

      # 顧客
      resources :customers do
        get :documents, on: :member
        get :credit_history, on: :member
        post :verify_invoice_number, on: :member
      end

      # 品目
      resources :products

      # 案件
      resources :projects do
        patch :status, on: :member
        get :documents, on: :member
        get :pipeline, on: :collection
      end

      # 帳票
      resources :documents do
        post :duplicate, on: :member
        post :convert, on: :member
        post :approve, on: :member
        post :reject, on: :member
        post :send_document, on: :member
        post :lock, on: :member
        get :pdf, on: :member
        get :versions, on: :member
        post :bulk_generate, on: :collection
      end

      # 入金
      resources :payments, only: [:index, :create, :destroy]

      # 銀行明細
      resources :bank_statements, only: [:index] do
        post :import, on: :collection
        get :unmatched, on: :collection
        post :match, on: :member
        post :ai_match, on: :collection
        post :ai_suggest, on: :member
      end

      # 督促
      namespace :dunning do
        resources :rules
        resources :logs, only: [:index]
        post :execute
      end

      # 回収
      namespace :collection do
        get :dashboard
        get :aging_report
        get :forecast
      end

      # データ移行
      resources :imports, only: [:create, :show] do
        get :preview, on: :member
        patch :mapping, on: :member
        post :execute, on: :member
        get :result, on: :member
      end

      # 通知
      resources :notifications, only: [:index, :update]

      # ダッシュボード
      get 'dashboard', to: 'dashboard#show'
    end
  end
end
```

### 3.2 サービスオブジェクト設計

#### 3.2.1 DocumentCalculator（金額計算）

```ruby
# app/services/document_calculator.rb
# REQ-DOC-002 対応
class DocumentCalculator
  # @param document [Document] 計算対象の帳票
  # @return [Document] 金額計算済みの帳票
  def call(document)
    # 1. 各明細行の金額計算: amount = (quantity * unit_price).floor
    # 2. 税率別集計（インボイス対応）
    # 3. subtotal / tax_amount / total_amount / remaining_amount 算出
  end
end
```

#### 3.2.2 AiBankMatcher（AI入金消込）

```ruby
# app/services/ai_bank_matcher.rb
# REQ-PAYMENT-003 対応
class AiBankMatcher
  CONFIDENCE_AUTO = 0.90
  CONFIDENCE_REVIEW = 0.70

  # @param bank_statements [Array<BankStatement>] 未消込の銀行明細
  # @return [Hash] { auto_matched: [], needs_review: [], unmatched: [] }
  def call(bank_statements)
    # Step 1: ルールベースフィルタリング（金額一致 ± 1円）
    # Step 2: 名義マッチング（正規化 + Levenshtein距離）
    # Step 3: AI補完（confidence < 0.7 をClaude Haikuに送信）
    # Step 4: 結果分類
    # Step 5: 自動消込実行（auto_matchedのみ）
  end
end
```

#### 3.2.3 CreditScoreCalculator（与信スコア）

```ruby
# app/services/credit_score_calculator.rb
# REQ-CUSTOMER-005 対応
class CreditScoreCalculator
  # @param customer [Customer] スコア算出対象
  # @return [Integer] 0-100の与信スコア
  def call(customer)
    # 基本スコア: 50
    # 加点/減点ロジック適用
    # 0〜100でクランプ
    # credit_score_histories に記録
  end
end
```

#### 3.2.4 DunningExecutor（督促実行）

```ruby
# app/services/dunning_executor.rb
# REQ-DUNNING-003 対応
class DunningExecutor
  # @param tenant [Tenant] 対象テナント
  # @return [Array<DunningLog>] 実行された督促のログ
  def call(tenant)
    # 1. 遅延中の請求書を取得
    # 2. 各請求書に対して適用可能なルールを判定
    # 3. テンプレート変数を置換してメール送信
    # 4. dunning_logs に記録
  end
end
```

#### 3.2.5 ImportExecutor（データ移行）

```ruby
# app/services/import_executor.rb
# REQ-IMPORT-004 対応
class ImportExecutor
  # @param import_job [ImportJob] 実行対象のジョブ
  # @return [Hash] { total:, success:, skipped:, error: }
  def call(import_job)
    # 1. parsed_data と column_mapping を使用
    # 2. 行ごとにバリデーション + DB挿入
    # 3. エラー行は error_details に記録
    # 4. import_stats 更新
  end
end
```

#### 3.2.6 AiColumnMapper（AI自動マッピング）

```ruby
# app/services/ai_column_mapper.rb
# REQ-IMPORT-003 対応
class AiColumnMapper
  # @param headers [Array<String>] CSVヘッダー
  # @param source_type [String] インポート元
  # @return [Hash] { mappings: [{source:, target_table:, target_column:, confidence:}], overall_confidence: }
  def call(headers, source_type)
    # 1. 既知フォーマットのパターンマッチング
    # 2. パターン不一致 → Claude Haiku API 呼び出し
    # 3. マッピング結果を返却
  end
end
```

### 3.3 フロントエンド: Next.js

#### 3.3.1 APIクライアント

```typescript
// src/lib/api-client.ts
/**
 * APIクライアント（JWT自動添付・リフレッシュ対応）
 */
class ApiClient {
  private baseUrl: string

  /**
   * GETリクエスト
   * @param path - APIパス
   * @param params - クエリパラメータ
   * @returns レスポンスデータ
   */
  async get<T>(path: string, params?: Record<string, string>): Promise<T>

  /**
   * POSTリクエスト（JSON）
   * @param path - APIパス
   * @param body - リクエストボディ
   * @returns レスポンスデータ
   */
  async post<T>(path: string, body?: unknown): Promise<T>

  /**
   * PATCHリクエスト
   */
  async patch<T>(path: string, body?: unknown): Promise<T>

  /**
   * DELETEリクエスト
   */
  async delete(path: string): Promise<void>

  /**
   * multipart/form-dataリクエスト（ファイルアップロード用）
   */
  async upload<T>(path: string, formData: FormData): Promise<T>
}
```

#### 3.3.2 認証コンテキスト

```typescript
// src/hooks/use-auth.ts
/**
 * 認証状態管理フック
 */
interface AuthContext {
  user: User | null
  tenant: Tenant | null
  isAuthenticated: boolean
  isLoading: boolean
  login: (email: string, password: string) => Promise<void>
  signup: (data: SignupData) => Promise<void>
  logout: () => Promise<void>
}
```

#### 3.3.3 共通レイアウト

```typescript
// src/app/(dashboard)/layout.tsx
/**
 * ダッシュボードレイアウト
 * - サイドバーナビゲーション
 * - ヘッダー（ユーザー名・通知ベル・テナント名）
 * - メインコンテンツエリア
 */
```

サイドバーメニュー構成:
| メニュー | パス | アイコン | ロール制限 |
|---------|------|---------|-----------|
| ダッシュボード | /dashboard | LayoutDashboard | 全員 |
| 回収管理 | /collection | BadgeJapaneseYen | owner/admin/accountant |
| 顧客 | /customers | Users | 全員 |
| 案件 | /projects | FolderKanban | 全員 |
| 帳票 | /documents | FileText | 全員 |
| 入金 | /payments | CreditCard | owner/admin/accountant |
| 督促 | /dunning | Bell | owner/admin/accountant |
| データ移行 | /import | Upload | owner/admin |
| レポート | /reports | BarChart | owner/admin/accountant |
| 設定 | /settings | Settings | 設定による |

---

## 4. Data Models

### 4.1 ER図（概要）

```
tenants ─┬─< users
         ├─< customers ─┬─< customer_contacts
         │              └─< credit_score_histories
         ├─< projects ──┬─< documents ─┬─< document_items
         │              │              ├─< document_versions
         │              │              ├─< payment_records
         │              │              └─< dunning_logs
         │              └─< project_notes (future)
         ├─< products
         ├─< bank_statements
         ├─< dunning_rules
         ├─< import_jobs
         ├─< recurring_rules
         ├─< notifications
         ├─< audit_logs
         └─< notification_settings (future)

industry_templates (master, tenant-independent)
import_column_definitions (master, tenant-independent)
```

### 4.2 主要テーブル概要

全テーブル定義は requirements.md の第2部に準拠。以下は設計上の重要ポイント。

#### 論理削除パターン
- tenants / users / customers / projects / documents に `deleted_at` カラム
- `default_scope { where(deleted_at: nil) }` は使用しない（明示的にスコープ適用）
- `paranoia` gem ではなく独自実装（シンプルに `scope :active, -> { where(deleted_at: nil) }`）

#### UUID公開パターン
- 外部公開用にはuuidを使用（URL, APIレスポンス）
- 内部FK参照にはbigint idを使用（パフォーマンス）
- APIのパスパラメータは全てuuid

#### JSONBカラム活用
- tags: 配列型 `["IT", "東京"]`
- custom_fields: オブジェクト型 `{"field1": "value"}`
- tax_summary: 構造化データ `[{"rate":10,"subtotal":100000,"tax":10000}]`
- sender_snapshot / recipient_snapshot: 発行時点の情報スナップショット

#### インデックス戦略
- テナント分離: `(tenant_id, ...)` の複合インデックスが基本
- 部分インデックス: `WHERE deleted_at IS NULL`, `WHERE document_type = 'invoice'` 等
- ユニーク制約: テナント内のメール、帳票番号等は部分ユニークインデックス

### 4.3 マイグレーション順序

1. `create_industry_templates` (マスタ、FK参照なし)
2. `create_tenants`
3. `create_users` (FK: tenants)
4. `create_customers` (FK: tenants)
5. `create_customer_contacts` (FK: customers)
6. `create_products` (FK: tenants)
7. `create_projects` (FK: tenants, customers, users)
8. `create_recurring_rules` (FK: tenants, customers, projects)
9. `create_documents` (FK: tenants, projects, customers, users, recurring_rules)
10. `create_document_items` (FK: documents, products)
11. `create_document_versions` (FK: documents, users)
12. `create_payment_records` (FK: tenants, documents, users)
13. `create_bank_statements` (FK: tenants, documents)
14. `create_dunning_rules` (FK: tenants)
15. `create_dunning_logs` (FK: tenants, documents, dunning_rules, customers)
16. `create_credit_score_histories` (FK: tenants, customers)
17. `create_import_jobs` (FK: tenants, users)
18. `create_import_column_definitions` (マスタ)
19. `create_notifications` (FK: tenants, users)
20. `create_audit_logs` (FK: tenants, users)

---

## 5. Error Handling

### 5.1 APIエラーレスポンス形式

```json
{
  "error": {
    "code": "validation_error",
    "message": "入力内容に誤りがあります",
    "details": [
      { "field": "email", "message": "メールアドレスの形式が正しくありません" }
    ]
  }
}
```

### 5.2 エラーコード一覧

| HTTPステータス | code | 用途 |
|--------------|------|------|
| 400 | validation_error | バリデーションエラー |
| 401 | unauthorized | 認証エラー（トークン無効/期限切れ） |
| 403 | forbidden | 認可エラー（権限不足） |
| 404 | not_found | リソース未発見 |
| 409 | conflict | 競合（楽観的ロック等） |
| 422 | unprocessable_entity | ビジネスロジックエラー |
| 422 | plan_limit_exceeded | プラン制限超過 |
| 422 | invalid_status_transition | 不正なステータス遷移 |
| 429 | rate_limited | レートリミット超過 |
| 500 | internal_error | サーバーエラー |

### 5.3 エラーハンドリング戦略

```ruby
# app/controllers/concerns/error_handler.rb
module ErrorHandler
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound do |e|
      render json: { error: { code: 'not_found', message: e.message } }, status: :not_found
    end

    rescue_from ActiveRecord::RecordInvalid do |e|
      render json: {
        error: {
          code: 'validation_error',
          message: '入力内容に誤りがあります',
          details: e.record.errors.map { |err| { field: err.attribute, message: err.full_message } }
        }
      }, status: :bad_request
    end

    rescue_from Pundit::NotAuthorizedError do
      render json: { error: { code: 'forbidden', message: '権限がありません' } }, status: :forbidden
    end

    rescue_from PlanLimitExceededError do |e|
      render json: { error: { code: 'plan_limit_exceeded', message: e.message } }, status: :unprocessable_entity
    end
  end
end
```

### 5.4 フロントエンド エラーハンドリング

```typescript
// src/lib/api-client.ts
// - 401: 自動的にリフレッシュトークンでリトライ → 失敗時はログイン画面にリダイレクト
// - 403: 権限エラーのトースト通知
// - 422 (plan_limit_exceeded): プランアップグレード促進モーダル
// - 429: レートリミットのトースト通知（リトライ情報付き）
// - 500: 一般エラーのトースト通知
```

---

## 6. Testing Strategy

### 6.1 バックエンド（RSpec）

| テスト種別 | 対象 | カバレッジ目標 |
|-----------|------|-------------|
| モデルテスト | バリデーション・スコープ・関連・コールバック | 90%以上 |
| リクエストテスト | 全APIエンドポイント | 100%（全エンドポイント） |
| サービステスト | 全サービスオブジェクト | 90%以上 |
| ジョブテスト | 全非同期ジョブ | 90%以上 |
| ポリシーテスト | Punditポリシー | 全ロール×全アクション |

#### テスト構成

```
spec/
├── models/
│   ├── tenant_spec.rb
│   ├── user_spec.rb
│   ├── customer_spec.rb
│   ├── document_spec.rb
│   └── ...
├── requests/
│   ├── api/v1/auth_spec.rb
│   ├── api/v1/customers_spec.rb
│   ├── api/v1/documents_spec.rb
│   ├── api/v1/payments_spec.rb
│   ├── api/v1/bank_statements_spec.rb
│   └── ...
├── services/
│   ├── document_calculator_spec.rb
│   ├── ai_bank_matcher_spec.rb
│   ├── credit_score_calculator_spec.rb
│   ├── dunning_executor_spec.rb
│   └── ...
├── jobs/
│   ├── invoice_overdue_check_job_spec.rb
│   └── ...
├── policies/
│   ├── customer_policy_spec.rb
│   └── ...
└── factories/
    ├── tenants.rb
    ├── users.rb
    ├── customers.rb
    └── ...
```

### 6.2 フロントエンド（Jest + RTL）

| テスト種別 | 対象 | カバレッジ目標 |
|-----------|------|-------------|
| コンポーネントテスト | 主要UIコンポーネント | 主要コンポーネント |
| フックテスト | カスタムフック | 全フック |
| ユーティリティテスト | ヘルパー関数 | 全関数 |

### 6.3 E2Eテスト（Playwright）

主要ユーザーフロー10本:
1. 新規登録 → ダッシュボード表示
2. 顧客作成 → 一覧表示
3. 見積書作成 → PDF生成 → メール送信
4. 見積書 → 請求書変換
5. 請求書作成 → 手動入金消込
6. 銀行明細CSV取込 → AI消込
7. 督促ルール設定 → 督促実行
8. データ移行ウィザード（Excel取込）
9. 回収ダッシュボード表示
10. 設定変更（自社情報・ユーザー管理）

---

## 7. Key Design Decisions

### Decision 1: SolidQueue over Sidekiq
**Context:** 非同期ジョブ基盤の選定
**Options:** 1) Sidekiq + Redis 2) SolidQueue (PostgreSQL-backed)
**Decision:** SolidQueue
**Rationale:** Redis不要でインフラコスト削減。Phase 1ではPuma内蔵モードで十分。ActiveJob互換で将来の移行も容易。

### Decision 2: JWT Authentication over Session
**Context:** API認証方式
**Options:** 1) Session-based 2) JWT (devise-jwt)
**Decision:** JWT (devise-jwt)
**Rationale:** API modeのRailsとNext.jsの分離アーキテクチャに適合。ステートレスでスケーラブル。

### Decision 3: Pundit over CanCanCan
**Context:** 認可フレームワーク
**Options:** 1) Pundit 2) CanCanCan
**Decision:** Pundit
**Rationale:** ポリシーベースで明示的。テスト容易。ロール×リソースの組み合わせが多い本プロジェクトに適合。

### Decision 4: UUID for external, bigint for internal
**Context:** ID戦略
**Options:** 1) UUID everywhere 2) bigint + UUID hybrid
**Decision:** bigint + UUID hybrid
**Rationale:** FK参照のパフォーマンスはbigintが優位。外部公開はUUIDで推測不可能性を確保。

### Decision 5: shadcn/ui over MUI/Ant Design
**Context:** UIコンポーネントライブラリ
**Options:** 1) shadcn/ui 2) MUI 3) Ant Design
**Decision:** shadcn/ui + Tailwind CSS
**Rationale:** コピーペースト方式でバンドルサイズ最小。Tailwindとの親和性。高いカスタマイズ性。

### Decision 6: Claude API model selection
**Context:** AI機能のモデル選定
**Options:** 1) Sonnet全タスク 2) タスク別使い分け
**Decision:** タスク別にSonnet/Haiku使い分け
**Rationale:** コスト最適化。パターンマッチ寄りの消込・マッピングはHaikuで十分。高精度が必要な見積提案はSonnet。

---

## Design Checklist
- [x] 全要件が設計でカバーされている
- [x] コンポーネント責務が明確に定義されている
- [x] コンポーネント間インターフェースが仕様化されている
- [x] エラーハンドリングが想定障害をカバーしている
- [x] セキュリティ考慮事項が対処されている
