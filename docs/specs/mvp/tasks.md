# ウケトリ MVP タスク計画

> **Phase:** Task Planning
> **Scope:** MVP Phase 1（12週間 - 全機能）
> **作成日:** 2026-02-27
> **依存関係:** requirements.md / design.md

---

## Week 1: 環境構築・DB設計

### 1.1 Docker環境構築
- [x] 1.1.1 プロジェクトルートに `docker-compose.yml` を作成
  - api / web / db / minio の4サービス定義
  - ボリューム定義（pg_data / api_bundle / web_node_modules / minio_data）
  - 環境変数設定（DATABASE_URL / R2_* / ANTHROPIC_API_KEY）
  - db の healthcheck 設定
  - _Requirements: REQ-INFRA-001_

- [x] 1.1.2 Rails API プロジェクトを作成
  - `api/` ディレクトリに Rails 7.2 API モードで新規作成
  - `api/Dockerfile.dev` を作成（ruby:3.3-slim ベース）
  - Gemfile に必要な gem を追加:
    - devise / devise-jwt (認証)
    - pundit (認可)
    - rack-cors (CORS)
    - rack-attack (レートリミット)
    - solid_queue / solid_cache
    - aws-sdk-s3 (ActiveStorage R2/MinIO用)
    - anthropic (Claude API)
    - sendgrid-ruby
    - rspec-rails / factory_bot_rails / faker / shoulda-matchers
  - `api/Dockerfile` を作成（本番用マルチステージビルド）
  - _Requirements: REQ-INFRA-001, REQ-INFRA-004_

- [x] 1.1.3 Next.js プロジェクトを作成
  - `web/` ディレクトリに Next.js 15 (App Router) + TypeScript で新規作成
  - `web/Dockerfile.dev` を作成（node:20-slim ベース）
  - Tailwind CSS + shadcn/ui をセットアップ
  - tsconfig.json で strict mode 有効、`any` 禁止設定
  - ESLint + Prettier 設定
  - _Requirements: REQ-INFRA-001_

- [x] 1.1.4 `.env.example` を作成
  - 全環境変数のテンプレート（要件定義書 付録A 準拠）
  - `.gitignore` に `.env` を追加

- [x] 1.1.5 `docker compose up` で全サービス起動確認
  - Rails API がポート3000で応答（`/api/v1/health`）
  - Next.js がポート3001で応答
  - PostgreSQL がポート5432で接続可能
  - MinIO がポート9000/9001で応答
  - _Requirements: REQ-INFRA-001_

### 1.2 Rails基盤設定
- [x] 1.2.1 database.yml を設定
  - 開発: Docker PostgreSQL (DATABASE_URL)
  - テスト: 別DB (uketori_test)
  - connect_timeout: 10（Neon対策）
  - _Requirements: REQ-INFRA-002_

- [x] 1.2.2 SolidQueue を設定
  - `config/solid_queue.yml` を作成（workers threads: 3, processes: 1）
  - `config/puma.rb` に `plugin :solid_queue` を追加（in-process mode）
  - SolidQueue 用マイグレーション実行
  - _Requirements: REQ-INFRA-004_

- [x] 1.2.3 SolidCache を設定
  - `config/solid_cache.yml` を作成
  - `config/environments/development.rb` で cache_store を設定
  - SolidCache 用マイグレーション実行
  - _Requirements: REQ-INFRA-004_

- [x] 1.2.4 ActiveStorage + S3互換 (MinIO/R2) を設定
  - `config/storage.yml` に S3互換設定（endpoint / key は環境変数）
  - MinIO の初期バケット作成スクリプト
  - _Requirements: REQ-INFRA-003_

- [x] 1.2.5 RSpec を設定
  - `spec/rails_helper.rb` / `spec/spec_helper.rb`
  - FactoryBot / Faker / Shoulda-matchers / DatabaseCleaner 設定
  - _Requirements: テスト方針_

- [x] 1.2.6 CORS を設定
  - `config/initializers/cors.rb` で Next.js からのアクセスを許可
  - 開発: `http://localhost:3001`

- [x] 1.2.7 Rack::Attack を設定
  - `config/initializers/rack_attack.rb`
  - 100req/min/user、ログイン5回/5min
  - _Requirements: REQ-AUTH-009_

### 1.3 データベースマイグレーション（全テーブル）
- [x] 1.3.1 マスタテーブルのマイグレーション作成
  - `create_industry_templates`
  - `create_import_column_definitions`
  - _Requirements: REQ-TENANT-002, REQ-IMPORT-002_

- [x] 1.3.2 テナント・ユーザーのマイグレーション作成
  - `create_tenants`（全カラム + インデックス）
  - `create_users`（全カラム + インデックス + ロール定義）
  - _Requirements: REQ-TENANT-001, REQ-AUTH-001_

- [x] 1.3.3 顧客関連のマイグレーション作成
  - `create_customers`（与信スコア・統計カラム含む）
  - `create_customer_contacts`
  - `create_credit_score_histories`
  - _Requirements: REQ-CUSTOMER-001, REQ-CUSTOMER-005_

- [x] 1.3.4 品目・案件のマイグレーション作成
  - `create_products`
  - `create_projects`（ステータス遷移定義含む）
  - _Requirements: REQ-PRODUCT-001, REQ-PROJECT-001_

- [x] 1.3.5 帳票関連のマイグレーション作成
  - `create_recurring_rules`
  - `create_documents`（入金ステータス・督促カラム含む）
  - `create_document_items`
  - `create_document_versions`
  - _Requirements: REQ-DOC-001, REQ-DOC-009_

- [x] 1.3.6 入金・銀行明細のマイグレーション作成
  - `create_payment_records`
  - `create_bank_statements`（AI消込関連カラム含む）
  - _Requirements: REQ-PAYMENT-001, REQ-PAYMENT-002_

- [x] 1.3.7 督促関連のマイグレーション作成
  - `create_dunning_rules`
  - `create_dunning_logs`
  - _Requirements: REQ-DUNNING-001_

- [x] 1.3.8 移行・通知・監査のマイグレーション作成
  - `create_import_jobs`
  - `create_notifications`
  - `create_audit_logs`
  - _Requirements: REQ-IMPORT-001, REQ-NOTIFICATION-001, REQ-AUDIT-001_

- [x] 1.3.9 Seeds データ作成
  - 業種テンプレート（6種）
  - インポートカラム定義（board対応）
  - _Requirements: REQ-TENANT-002, REQ-IMPORT-002_

### 1.4 モデル定義（全モデル）
- [x] 1.4.1 テナント・ユーザーモデル
  - `Tenant` モデル（バリデーション・関連・スコープ）
  - `User` モデル（Devise設定・ロール・バリデーション）
  - `TenantScoped` concern（マルチテナント分離）
  - `Current` クラス（ActiveSupport::CurrentAttributes）
  - _Requirements: REQ-AUTH-008_

- [x] 1.4.2 顧客関連モデル
  - `Customer` モデル（バリデーション・スコープ・与信スコア関連）
  - `CustomerContact` モデル
  - `CreditScoreHistory` モデル
  - _Requirements: REQ-CUSTOMER-001_

- [x] 1.4.3 品目・案件モデル
  - `Product` モデル（バリデーション・スコープ）
  - `Project` モデル（ステートマシン・バリデーション）
  - _Requirements: REQ-PRODUCT-001, REQ-PROJECT-002_

- [x] 1.4.4 帳票関連モデル
  - `Document` モデル（ステータス遷移・金額計算コールバック・バリデーション）
  - `DocumentItem` モデル
  - `DocumentVersion` モデル
  - `RecurringRule` モデル
  - _Requirements: REQ-DOC-001, REQ-DOC-003_

- [x] 1.4.5 入金・銀行明細モデル
  - `PaymentRecord` モデル（消込ロジック・コールバック）
  - `BankStatement` モデル
  - _Requirements: REQ-PAYMENT-001_

- [x] 1.4.6 督促関連モデル
  - `DunningRule` モデル（テンプレート変数定義）
  - `DunningLog` モデル
  - _Requirements: REQ-DUNNING-001_

- [x] 1.4.7 その他モデル
  - `ImportJob` モデル（ステータス遷移）
  - `ImportColumnDefinition` モデル
  - `IndustryTemplate` モデル
  - `Notification` モデル
  - `AuditLog` モデル
  - _Requirements: REQ-IMPORT-001, REQ-NOTIFICATION-001, REQ-AUDIT-001_

### 1.5 Next.js 基盤セットアップ
- [x] 1.5.1 TypeScript型定義を作成
  - `src/types/` に全エンティティの型定義
  - API レスポンス/リクエストの型定義
  - _Requirements: 技術スタック_

- [x] 1.5.2 APIクライアントを実装
  - `src/lib/api-client.ts`（JWT自動添付・リフレッシュ・エラーハンドリング）
  - _Requirements: REQ-AUTH-002, REQ-AUTH-003_

- [x] 1.5.3 共通レイアウト・UIコンポーネント初期セットアップ
  - shadcn/ui の必要コンポーネントをインストール
  - `src/app/layout.tsx`（ルートレイアウト）
  - `src/app/(auth)/layout.tsx`（認証ページレイアウト）
  - `src/app/(dashboard)/layout.tsx`（サイドバー付きレイアウト）
  - サイドバー / ヘッダー / ブレッドクラム コンポーネント

---

## Week 2: 認証・テナント・ユーザー管理

### 2.1 認証API（バックエンド）
- [x] 2.1.1 JWT認証サービスを実装
  - `app/services/jwt_service.rb`（encode / decode / refresh）
  - アクセストークン有効期限: 15分 / リフレッシュトークン: 7日
  - _Requirements: REQ-AUTH-002, REQ-AUTH-003_

- [x] 2.1.2 サインアップAPIを実装
  - `POST /api/v1/auth/sign_up`
  - テナント + オーナーユーザーの同時作成（トランザクション）
  - バリデーション（メール形式・パスワード強度・テナント名・業種）
  - 業種テンプレートに基づくデフォルト品目・督促ルールの自動作成
  - _Requirements: REQ-AUTH-001_

- [x] 2.1.3 サインイン / サインアウト / リフレッシュAPIを実装
  - `POST /api/v1/auth/sign_in`
  - `DELETE /api/v1/auth/sign_out`
  - `POST /api/v1/auth/refresh`
  - _Requirements: REQ-AUTH-002, REQ-AUTH-003, REQ-AUTH-004_

- [x] 2.1.4 パスワードリセットAPIを実装
  - `POST /api/v1/auth/password/reset`
  - `PATCH /api/v1/auth/password/update`
  - リセットトークン生成・メール送信
  - _Requirements: REQ-AUTH-005_

- [x] 2.1.5 招待APIを実装
  - `POST /api/v1/users/invite`
  - `POST /api/v1/auth/invitation/accept`
  - 招待トークン生成・メール送信
  - _Requirements: REQ-AUTH-006_

### 2.2 認可（Pundit）
- [x] 2.2.1 Punditポリシーを実装
  - `ApplicationPolicy`（ベースポリシー）
  - 各リソースのポリシー（ロール×アクション マトリクス）
  - _Requirements: REQ-AUTH-007_

### 2.3 ユーザー管理API
- [x] 2.3.1 ユーザーCRUD APIを実装
  - `GET/POST/PATCH/DELETE /api/v1/users`
  - ロール変更・プラン制限チェック（ユーザー数上限）
  - _Requirements: REQ-AUTH-006, REQ-PLAN-001_

### 2.4 認証・テナントRSpecテスト
- [x] 2.4.1 認証API のリクエストテスト
  - サインアップ（正常系・バリデーションエラー・重複メール）
  - サインイン（正常系・認証エラー・レートリミット）
  - トークンリフレッシュ・ログアウト
  - パスワードリセット・招待

- [x] 2.4.2 Punditポリシーのテスト
  - 全ロール × 全アクションのマトリクステスト

### 2.5 認証UI（フロントエンド）
- [x] 2.5.1 認証フック・コンテキストを実装
  - `src/hooks/use-auth.ts`（ログイン/登録/ログアウト/状態管理）
  - JWT をlocalStorageに保存、リフレッシュ自動実行

- [x] 2.5.2 ログイン画面を実装
  - `/login` ページ（メール・パスワード入力）
  - バリデーション・エラー表示
  - _Requirements: REQ-AUTH-002_

- [x] 2.5.3 新規登録画面を実装
  - `/signup` ページ（テナント名・業種・ユーザー名・メール・パスワード）
  - 業種選択ドロップダウン
  - _Requirements: REQ-AUTH-001_

- [x] 2.5.4 パスワードリセット画面を実装
  - `/password/reset` ページ
  - _Requirements: REQ-AUTH-005_

- [x] 2.5.5 認証ガード（ミドルウェア）を実装
  - 未認証ユーザーのリダイレクト
  - ロールベースのページアクセス制御

---

## Week 3: 自社情報設定・業種テンプレート

### 3.1 テナント設定API
- [x] 3.1.1 テナント情報 CRUD API を実装
  - `GET/PATCH /api/v1/tenant`
  - 自社情報（会社名・住所・銀行口座・適格番号等）
  - _Requirements: REQ-TENANT-001_

- [x] 3.1.2 ロゴ・印影アップロードAPIを実装
  - ActiveStorage 経由で R2/MinIO に保存
  - 署名付きURL発行（有効期限30分）
  - _Requirements: REQ-TENANT-003_

- [x] 3.1.3 適格番号検証ジョブを実装
  - `InvoiceNumberVerificationJob`
  - 国税庁APIクライアント（レート制限: 1回/秒）
  - _Requirements: REQ-CUSTOMER-004_

### 3.2 設定画面（フロントエンド）
- [x] 3.2.1 自社情報設定画面を実装
  - `/settings/company` ページ
  - フォーム（会社名・住所・電話・FAX・銀行口座・適格番号）
  - ロゴ/印影アップロードコンポーネント
  - _Requirements: REQ-TENANT-001, REQ-TENANT-003_

- [x] 3.2.2 業種テンプレート設定画面を実装
  - `/settings/industry` ページ
  - 業種選択→用語・品目の切り替えプレビュー
  - _Requirements: REQ-TENANT-002_

- [x] 3.2.3 帳票採番・デフォルト設定画面を実装
  - 採番フォーマット・支払期日・税率・会計年度
  - _Requirements: REQ-TENANT-004, REQ-TENANT-005_

### 3.3 テスト
- [x] 3.3.1 テナントAPIのリクエストテスト
- [x] 3.3.2 適格番号検証ジョブのテスト

---

## Week 4: 顧客マスタ管理

### 4.1 顧客API
- [x] 4.1.1 顧客CRUD APIを実装
  - `GET/POST/PATCH/DELETE /api/v1/customers`
  - フィルタ・ソート・ページネーション（全パラメータ対応）
  - プラン制限チェック（顧客数上限）
  - _Requirements: REQ-CUSTOMER-001, REQ-CUSTOMER-002, REQ-PLAN-001_

- [x] 4.1.2 顧客担当者APIを実装
  - 顧客のネストリソースとして CRUD
  - _Requirements: REQ-CUSTOMER-003_

- [x] 4.1.3 顧客適格番号検証APIを実装
  - `POST /api/v1/customers/:uuid/verify_invoice_number`
  - _Requirements: REQ-CUSTOMER-004_

- [x] 4.1.4 与信スコア履歴APIを実装
  - `GET /api/v1/customers/:uuid/credit_history`
  - _Requirements: REQ-CUSTOMER-005_

### 4.2 顧客画面（フロントエンド）
- [x] 4.2.1 顧客一覧画面を実装
  - `/customers` ページ
  - テーブル表示（ページネーション・ソート・フィルタ）
  - 検索・タグフィルタ・与信スコアフィルタ
  - _Requirements: REQ-CUSTOMER-001, REQ-CUSTOMER-002_

- [x] 4.2.2 顧客詳細画面を実装
  - `/customers/:uuid` ページ
  - 基本情報・担当者一覧・帳票一覧・与信スコア履歴

- [x] 4.2.3 顧客作成・編集画面を実装
  - `/customers/:uuid/edit` ページ
  - フォーム（全フィールド + 担当者管理）
  - 適格番号入力→検証ボタン

### 4.3 テスト
- [x] 4.3.1 Customer モデルのテスト
- [x] 4.3.2 顧客APIのリクエストテスト（全エンドポイント）
- [x] 4.3.3 CustomerPolicy のテスト

---

## Week 5: 品目マスタ + 見積書作成・編集

### 5.1 品目API
- [x] 5.1.1 品目CRUD APIを実装
  - `GET/POST/PATCH/DELETE /api/v1/products`
  - ソート・有効/無効フィルタ
  - _Requirements: REQ-PRODUCT-001, REQ-PRODUCT-002_

### 5.2 帳票基盤（バックエンド）
- [x] 5.2.1 DocumentCalculator サービスを実装
  - 明細行の金額計算（quantity × unit_price）
  - 税率別集計（インボイス対応）
  - subtotal / tax_amount / total_amount / remaining_amount 算出
  - _Requirements: REQ-DOC-002_

- [x] 5.2.2 DocumentNumberGenerator サービスを実装
  - テナントの採番フォーマットに基づく自動採番
  - テナント内・タイプ内ユニーク保証
  - _Requirements: REQ-TENANT-004_

- [x] 5.2.3 帳票CRUD APIを実装
  - `GET/POST/PATCH/DELETE /api/v1/documents`
  - 帳票タイプフィルタ・ステータスフィルタ
  - 作成時に金額自動計算
  - プラン制限チェック（帳票作成数上限）
  - _Requirements: REQ-DOC-001, REQ-PLAN-001_

- [x] 5.2.4 帳票ステータス遷移を実装
  - ステートマシン（draft → approved → sent → locked 等）
  - 不正遷移の422エラー
  - _Requirements: REQ-DOC-003_

- [x] 5.2.5 帳票バージョン管理を実装
  - 更新時にdocument_versionsにスナップショット保存
  - `GET /api/v1/documents/:uuid/versions`
  - _Requirements: REQ-DOC-008_

- [x] 5.2.6 AuditLogger サービスを実装
  - 全CUD操作のaudit_logs記録
  - _Requirements: REQ-AUDIT-001_

### 5.3 見積書UI（フロントエンド）
- [x] 5.3.1 帳票一覧画面を実装
  - `/documents` ページ
  - タイプ別タブ（見積書/請求書/...）
  - テーブル表示（ページネーション・ソート・フィルタ）
  - _Requirements: REQ-DOC-001_

- [x] 5.3.2 帳票作成・編集画面を実装
  - `/documents/:uuid/edit` ページ
  - 左パネル: 入力フォーム（顧客選択・案件選択・発行日・明細行）
  - 右パネル: リアルタイムPDFプレビュー（後でPDF生成実装後に接続）
  - 明細行の動的追加/削除/並べ替え
  - 品目マスタからの自動入力
  - 金額自動計算（フロントエンド側もリアルタイム表示）
  - _Requirements: REQ-DOC-001, REQ-DOC-010_

### 5.4 テスト
- [x] 5.4.1 DocumentCalculator のサービステスト
- [x] 5.4.2 Document モデルのテスト（バリデーション・ステータス遷移）
- [x] 5.4.3 帳票APIのリクエストテスト

---

## Week 6: 見積書PDF生成・メール送信

### 6.1 PDF生成（バックエンド）
- [x] 6.1.1 PdfGenerator サービスを実装
  - インボイス対応PDFレイアウト
  - 自社情報スナップショット / 顧客情報スナップショット
  - 適格請求書番号・税率別集計の表示
  - ロゴ・印影の埋め込み
  - R2/MinIOへのアップロード
  - _Requirements: REQ-DOC-005_

- [x] 6.1.2 PdfGenerationJob を実装
  - 非同期PDF生成（SolidQueue）
  - 生成完了後に pdf_url / pdf_generated_at を更新
  - _Requirements: REQ-DOC-005_

- [x] 6.1.3 PDF取得APIを実装
  - `GET /api/v1/documents/:uuid/pdf`
  - 署名付きURL発行
  - 未生成の場合は新規生成をトリガー

### 6.2 メール送信（バックエンド）
- [x] 6.2.1 DocumentMailer を実装
  - 帳票メール送信（PDFを添付 or ダウンロードリンク）
  - SendGrid連携
  - _Requirements: REQ-DOC-006_

- [x] 6.2.2 帳票送信APIを実装
  - `POST /api/v1/documents/:uuid/send_document`
  - sent_at / sent_method の記録
  - ステータスを 'sent' に遷移
  - _Requirements: REQ-DOC-006_

### 6.3 電子帳簿保存法対応
- [x] 6.3.1 帳票ロック機能を実装
  - `POST /api/v1/documents/:uuid/lock`
  - locked_at のタイムスタンプ記録
  - ロック後の変更を禁止（新バージョン作成のみ可）
  - _Requirements: REQ-DOC-007_

### 6.4 フロントエンド
- [x] 6.4.1 帳票プレビュー画面を実装
  - `/documents/:uuid/preview` ページ
  - PDF表示 / ダウンロード
  - _Requirements: REQ-DOC-005_

- [x] 6.4.2 メール送信モーダルを実装
  - 送信先選択・件名・本文入力
  - _Requirements: REQ-DOC-006_

### 6.5 テスト
- [x] 6.5.1 PdfGenerator のサービステスト
- [x] 6.5.2 DocumentMailer のテスト
- [x] 6.5.3 帳票ロックのテスト

---

## Week 7: 請求書作成（見積→請求変換含む）

### 7.1 帳票変換（バックエンド）
- [x] 7.1.1 DocumentConverter サービスを実装
  - estimate → invoice / purchase_order
  - purchase_order → delivery_note / invoice
  - invoice → receipt（入金完了済みチェック）
  - 品目コピー・parent_document_id設定
  - _Requirements: REQ-DOC-004_

- [x] 7.1.2 帳票変換APIを実装
  - `POST /api/v1/documents/:uuid/convert`
  - _Requirements: REQ-DOC-004_

- [x] 7.1.3 帳票複製APIを実装
  - `POST /api/v1/documents/:uuid/duplicate`

### 7.2 請求書固有機能
- [x] 7.2.1 請求書入金ステータス管理を実装
  - payment_status の自動更新（入金記録時）
  - remaining_amount の自動計算
  - _Requirements: REQ-DOC-009_

### 7.3 フロントエンド
- [x] 7.3.1 帳票変換UIを実装
  - 見積書詳細画面に「請求書に変換」ボタン
  - 変換先タイプ選択モーダル
  - _Requirements: REQ-DOC-004_

- [x] 7.3.2 請求書固有フィールドUIを実装
  - 支払期日入力
  - 入金ステータス表示

### 7.4 テスト
- [x] 7.4.1 DocumentConverter のサービステスト
- [x] 7.4.2 帳票変換APIのリクエストテスト

---

## Week 8: 請求書PDF・送信 + 入金管理（手動消込）

### 8.1 入金管理API（バックエンド）
- [x] 8.1.1 入金記録CRUD APIを実装
  - `GET/POST/DELETE /api/v1/payments`
  - 入金記録作成時: payment_records作成 → documents.paid_amount / remaining_amount / payment_status 更新 → customers.total_outstanding 再計算
  - 入金取消時: 逆計算
  - _Requirements: REQ-PAYMENT-001_

### 8.2 入金管理画面（フロントエンド）
- [x] 8.2.1 入金一覧画面を実装
  - `/payments` ページ
  - テーブル表示（日付・顧客・請求書番号・金額・方法）

- [x] 8.2.2 入金記録フォームを実装
  - 請求書選択→金額入力→支払方法選択→記録
  - _Requirements: REQ-PAYMENT-001_

### 8.3 テスト
- [x] 8.3.1 入金記録の作成・取消テスト
- [x] 8.3.2 請求書の入金ステータス自動更新テスト
- [x] 8.3.3 入金APIのリクエストテスト

---

## Week 9: ★銀行明細CSV取込 + AI入金消込

### 9.1 銀行明細取込（バックエンド）
- [x] 9.1.1 BankStatementImporter サービスを実装
  - CSVパース（Shift_JIS / UTF-8 自動判定）
  - 銀行別フォーマット判定・カラムマッピング
  - 重複チェック
  - DB保存
  - _Requirements: REQ-PAYMENT-002_

- [x] 9.1.2 銀行明細取込APIを実装
  - `POST /api/v1/bank_statements/import`（multipart/form-data）
  - 取込後にAiBankMatchJobを非同期キュー投入
  - _Requirements: REQ-PAYMENT-002_

- [x] 9.1.3 銀行明細一覧・未消込APIを実装
  - `GET /api/v1/bank_statements`
  - `GET /api/v1/bank_statements/unmatched`

### 9.2 AI入金消込（バックエンド）
- [x] 9.2.1 AiBankMatcher サービスを実装
  - Step 1: ルールベースフィルタリング（金額一致 ± 1円）
  - Step 2: 名義マッチング（カタカナ正規化・Levenshtein距離）
  - Step 3: AI補完（Claude Haiku API）
  - Step 4: 結果分類（auto/review/unmatched）
  - Step 5: 自動消込実行
  - _Requirements: REQ-PAYMENT-003_

- [x] 9.2.2 AiBankMatchJob を実装
  - SolidQueueで非同期実行
  - _Requirements: REQ-PAYMENT-003_

- [x] 9.2.3 AI消込関連APIを実装
  - `POST /api/v1/bank_statements/ai_match`
  - `POST /api/v1/bank_statements/:id/ai_suggest`
  - `POST /api/v1/bank_statements/:id/match`（手動消込）
  - _Requirements: REQ-PAYMENT-003, REQ-PAYMENT-004_

### 9.3 銀行明細・AI消込UI（フロントエンド）
- [x] 9.3.1 銀行明細取込画面を実装
  - `/payments/bank-import` ページ
  - Step 1: CSVドラッグ＆ドロップ + 銀行選択
  - Step 2: AI消込結果表示（自動消込済み/要確認/未マッチの3カテゴリ）
  - 要確認: AI候補（確信度バー）+ 確定/変更/スキップボタン
  - 未マッチ: 手動消込ボタン
  - _Requirements: REQ-PAYMENT-004_

### 9.4 テスト
- [x] 9.4.1 BankStatementImporter のサービステスト（各銀行フォーマット・文字コード）
- [x] 9.4.2 AiBankMatcher のサービステスト（全ステップ）
- [x] 9.4.3 銀行明細APIのリクエストテスト

---

## Week 10: ★督促管理 + 回収ダッシュボード

### 10.1 督促管理（バックエンド）
- [x] 10.1.1 DunningExecutor サービスを実装
  - 遅延請求書の検出
  - ルール適用判定（trigger_days / max_count / interval）
  - テンプレート変数の置換
  - メール送信（DunningMailer）
  - dunning_logs記録
  - _Requirements: REQ-DUNNING-003_

- [x] 10.1.2 DunningExecutionJob を実装
  - 毎日10:00実行（SolidQueue recurring）
  - _Requirements: REQ-DUNNING-003_

- [x] 10.1.3 InvoiceOverdueCheckJob を実装
  - 毎日9:00実行 — 支払期日超過の請求書を検出 → overdue に更新 → 通知作成
  - _Requirements: REQ-DOC-009_

- [x] 10.1.4 督促ルールCRUD APIを実装
  - `GET/POST/PATCH/DELETE /api/v1/dunning/rules`
  - _Requirements: REQ-DUNNING-001_

- [x] 10.1.5 督促履歴APIを実装
  - `GET /api/v1/dunning/logs`
  - `POST /api/v1/dunning/execute`（手動実行）
  - _Requirements: REQ-DUNNING-004_

### 10.2 回収ダッシュボード（バックエンド）
- [x] 10.2.1 回収ダッシュボードAPIを実装
  - `GET /api/v1/collection/dashboard`
  - KPI集計（未回収合計・遅延金額・回収率・DSO）
  - エイジング集計
  - 要注意取引先リスト
  - 回収トレンド
  - 入金予定
  - _Requirements: REQ-COLLECTION-001, REQ-COLLECTION-004, REQ-COLLECTION-005_

- [x] 10.2.2 売掛金年齢表APIを実装
  - `GET /api/v1/collection/aging_report`
  - 顧客別・期間別の売掛金集計
  - _Requirements: REQ-COLLECTION-002_

### 10.3 与信スコア定期計算
- [x] 10.3.1 CreditScoreCalculator サービスを実装
  - 加点/減点ロジック（要件定義書 2.2.15 準拠）
  - _Requirements: REQ-CUSTOMER-005_

- [x] 10.3.2 CreditScoreCalculationJob を実装
  - 毎日2:00実行
  - _Requirements: REQ-CUSTOMER-005_

- [x] 10.3.3 CustomerStatsUpdateJob を実装
  - 毎日3:00実行
  - _Requirements: REQ-CUSTOMER-006_

### 10.4 フロントエンド
- [x] 10.4.1 回収ダッシュボード画面を実装
  - `/collection` ページ
  - KPIカード / エイジングチャート / 要注意取引先 / 回収トレンド / 未消込アラート
  - _Requirements: REQ-COLLECTION-001_

- [x] 10.4.2 売掛金年齢表画面を実装
  - `/collection/aging` ページ
  - 顧客別テーブル（期間区分別金額）
  - _Requirements: REQ-COLLECTION-002_

- [x] 10.4.3 督促管理画面を実装
  - `/dunning` ページ
  - 督促ルール一覧 / 履歴 / 手動実行ボタン
  - _Requirements: REQ-DUNNING-001_

- [x] 10.4.4 督促ルール設定画面を実装
  - `/settings/dunning` ページ
  - ルール作成/編集フォーム（テンプレート変数のプレビュー付き）
  - _Requirements: REQ-DUNNING-001_

### 10.5 テスト
- [x] 10.5.1 DunningExecutor のサービステスト
- [x] 10.5.2 CreditScoreCalculator のサービステスト
- [x] 10.5.3 回収ダッシュボード / 売掛金年齢表APIのテスト
- [x] 10.5.4 InvoiceOverdueCheckJob のテスト

---

## Week 11: ★データ移行ウィザード

### 11.1 データ移行（バックエンド）
- [x] 11.1.1 AiColumnMapper サービスを実装
  - 既知フォーマット（board）のパターンマッチング
  - 不明フォーマット → Claude Haiku API でマッピング提案
  - _Requirements: REQ-IMPORT-003_

- [x] 11.1.2 ImportExecutor サービスを実装
  - parsed_data + column_mapping でDB挿入
  - バリデーション・エラーハンドリング
  - import_stats / error_details の記録
  - _Requirements: REQ-IMPORT-004_

- [x] 11.1.3 ImportExecutionJob を実装
  - SolidQueueで非同期実行
  - _Requirements: REQ-IMPORT-004_

- [x] 11.1.4 移行API を実装
  - `POST /api/v1/imports`（ファイルアップロード）
  - `GET /api/v1/imports/:uuid`（ステータス取得）
  - `GET /api/v1/imports/:uuid/preview`（プレビュー）
  - `PATCH /api/v1/imports/:uuid/mapping`（マッピング修正）
  - `POST /api/v1/imports/:uuid/execute`（実行）
  - `GET /api/v1/imports/:uuid/result`（結果）
  - _Requirements: REQ-IMPORT-001_

### 11.2 データ移行UI（フロントエンド）
- [x] 11.2.1 移行ウィザード画面を実装
  - `/import` ページ
  - Step 1: 移行元選択（board / Excel / CSV アイコンボタン）
  - Step 2: ファイルアップロード（ドラッグ＆ドロップ + 手順説明）
  - Step 3: AIマッピング確認（元カラム ↔ ウケトリカラム + 確信度バー + 変更ドロップダウン）
  - Step 4: プレビュー（先頭10件テーブル + エラーハイライト）
  - Step 5: 実行＆結果（プログレスバー → 成功/スキップ/エラー件数）
  - _Requirements: REQ-IMPORT-003, REQ-IMPORT-004, REQ-IMPORT-005_

### 11.3 テスト
- [x] 11.3.1 AiColumnMapper のサービステスト（board / Excel / CSV）
- [x] 11.3.2 ImportExecutor のサービステスト
- [x] 11.3.3 移行APIのリクエストテスト

---

## Week 12: ダッシュボード + テスト + バグ修正

### 12.1 メインダッシュボード（バックエンド）
- [x] 12.1.1 ダッシュボードAPIを実装
  - `GET /api/v1/dashboard`
  - KPI集計（月次売上・未回収金額・回収率）
  - 売上推移データ
  - 入金予定カレンダーデータ
  - 最近の取引一覧（直近10件）
  - 案件パイプラインデータ
  - 期間切替（月/四半期/年度）
  - _Requirements: REQ-DASHBOARD-001 〜 005_

### 12.2 メインダッシュボード（フロントエンド）
- [x] 12.2.1 ダッシュボード画面を実装
  - `/dashboard` ページ
  - KPIカード×4（前期比付き）
  - 入金回収アラート（赤背景、遅延時表示）
  - 売上推移グラフ（recharts等）
  - 入金予定カレンダー
  - 最近の取引一覧
  - 案件パイプライン横棒
  - 期間切替タブ
  - _Requirements: REQ-DASHBOARD-001 〜 005_

### 12.3 通知機能
- [x] 12.3.1 通知APIを実装
  - `GET /api/v1/notifications`（未読一覧）
  - `PATCH /api/v1/notifications/:id`（既読更新）
  - _Requirements: REQ-NOTIFICATION-002_

- [x] 12.3.2 通知UIを実装
  - ヘッダーの通知ベルアイコン
  - 未読バッジ
  - ドロップダウン通知一覧

### 12.4 定期ジョブ設定
- [x] 12.4.1 `config/recurring.yml` を完成
  - 全定期ジョブの登録
  - _Requirements: REQ-JOB-001_

### 12.5 プラン制限
- [x] 12.5.1 PlanLimitChecker サービスを実装
  - 全リソースの制限チェック
  - _Requirements: REQ-PLAN-001_

### 12.6 設定画面（残り）
- [x] 12.6.1 ユーザー管理画面を実装
  - `/settings/users` ページ
  - 招待・ロール変更・削除

- [x] 12.6.2 通知設定画面を実装
  - `/settings/notifications` ページ

### 12.7 統合テスト・バグ修正
- [x] 12.7.1 全APIエンドポイントのリクエストテスト最終確認
- [ ] 12.7.2 E2Eテスト（Playwright）— 主要フロー10本
  1. 新規登録 → ダッシュボード
  2. 顧客CRUD
  3. 見積書作成 → PDF → メール送信
  4. 見積書 → 請求書変換
  5. 請求書 → 手動入金消込
  6. 銀行明細CSV取込 → AI消込
  7. 督促ルール設定 → 実行
  8. データ移行ウィザード
  9. 回収ダッシュボード
  10. 設定変更
- [ ] 12.7.3 バグ修正・パフォーマンス調整
- [x] 12.7.4 CI/CDパイプライン（GitHub Actions）設定
  - `.github/workflows/deploy.yml`

---

## Tasks Checklist
- [x] 全設計コンポーネントに実装タスクがある
- [x] タスクは依存関係を尊重した順序で並んでいる
- [x] 各タスクがテスト可能なコードを生成する
- [x] 要件参照が含まれている
- [x] タスクスコープが適切（各タスク2-4時間目安）
