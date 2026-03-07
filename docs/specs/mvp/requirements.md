# ウケトリ MVP 要件定義書（EARS形式）

> **Phase:** Requirements Gathering
> **Scope:** MVP Phase 1（12週間 - 全機能）
> **作成日:** 2026-02-27
> **元要件定義書:** docs/requirements.md v1.1

---

## 1. 環境構築・インフラ

### REQ-INFRA-001: Docker開発環境
- WHEN 開発者が `docker compose up` を実行する THEN システム SHALL Rails API / Next.js / PostgreSQL / MinIO の全サービスを起動する
- WHEN 全サービスが起動する THEN Rails API SHALL ポート3000で、Next.js SHALL ポート3001で、PostgreSQL SHALL ポート5432で、MinIO SHALL ポート9000/9001でアクセス可能になる
- WHEN Rails APIコンテナが起動する THEN システム SHALL SolidQueueをPuma内蔵モードで実行する（SOLID_QUEUE_IN_PUMA=true）

### REQ-INFRA-002: データベース
- WHEN システムが初回起動する THEN データベース SHALL 全テーブルのマイグレーションを完了する
- WHEN マイグレーションが完了する THEN データベース SHALL SolidQueue / SolidCache用の内部テーブルも作成する
- システム SHALL PostgreSQL 16.xを使用する

### REQ-INFRA-003: ファイルストレージ
- システム SHALL S3互換API（開発: MinIO / 本番: Cloudflare R2）でファイルを保存する
- WHEN ファイルをアップロードする THEN ActiveStorage SHALL S3互換APIを通じてストレージに保存する
- WHEN 開発環境と本番環境を切り替える THEN 環境変数の変更のみ SHALL で動作する

### REQ-INFRA-004: 非同期ジョブ
- システム SHALL SolidQueue（PostgreSQL-backed）を使用する（Redis不要）
- WHEN Phase 1（0〜100ユーザー） THEN SolidQueue SHALL Puma内蔵モード（in-process）で実行する
- システム SHALL Sidekiq / Redisを使用しない

---

## 2. 認証・認可

### REQ-AUTH-001: ユーザー登録（テナント作成）
- WHEN ユーザーが有効なメール・パスワード・テナント情報を提供する THEN システム SHALL 新規テナントとオーナーユーザーを作成し、JWTを発行する
- WHEN ユーザーが既存メールアドレスを提供する THEN システム SHALL 「このメールアドレスは既に登録されています」エラーを返す
- WHEN パスワードが8文字未満または英大小数字記号の各1文字以上を満たさない THEN システム SHALL バリデーションエラーを返す
- WHEN テナント名が空または255文字超 THEN システム SHALL バリデーションエラーを返す
- WHEN industry_typeがindustry_templates.codeに存在しない THEN システム SHALL バリデーションエラーを返す

### REQ-AUTH-002: ログイン
- WHEN ユーザーが正しいメール・パスワードを提供する THEN システム SHALL JWTアクセストークン（有効期限15分）とリフレッシュトークン（有効期限7日）を発行する
- WHEN ユーザーが誤ったメール・パスワードを提供する THEN システム SHALL 401エラーを返す
- WHEN ログイン試行が5回/5分を超える THEN システム SHALL レートリミットエラー（429）を返す

### REQ-AUTH-003: トークンリフレッシュ
- WHEN 有効なリフレッシュトークンを提供する THEN システム SHALL 新しいアクセストークンを発行する
- WHEN 期限切れまたは無効なリフレッシュトークンを提供する THEN システム SHALL 401エラーを返す

### REQ-AUTH-004: ログアウト
- WHEN ユーザーがログアウトする THEN システム SHALL 現在のトークンを無効化する

### REQ-AUTH-005: パスワードリセット
- WHEN ユーザーがパスワードリセットを要求する THEN システム SHALL リセットトークンを生成しメールを送信する
- WHEN 有効なリセットトークンと新パスワードを提供する THEN システム SHALL パスワードを更新する

### REQ-AUTH-006: ユーザー招待
- WHEN オーナー/管理者がメンバーを招待する THEN システム SHALL 招待トークンを生成しメールを送信する
- WHEN ユーザーが招待を受諾する THEN システム SHALL テナントにメンバーとして追加する

### REQ-AUTH-007: 認可（ロールベース）
- システム SHALL 5つのロール（owner / admin / accountant / sales / member）を提供する
- WHEN owner THEN ユーザー SHALL 全権限を持つ（プラン変更・テナント削除を含む）
- WHEN admin THEN ユーザー SHALL ユーザー管理・設定変更が可能（プラン変更は不可）
- WHEN accountant THEN ユーザー SHALL 全帳票・入金・レポートの閲覧・編集が可能（ユーザー管理は不可）
- WHEN sales THEN ユーザー SHALL 自分担当の案件・帳票の作成・編集が可能（入金管理は閲覧のみ）
- WHEN member THEN ユーザー SHALL 閲覧のみ可能

### REQ-AUTH-008: マルチテナント分離
- システム SHALL 全てのデータアクセスにtenant_idによる行レベルフィルタリングを適用する
- WHEN ユーザーが他テナントのデータにアクセスしようとする THEN システム SHALL 404エラーを返す

### REQ-AUTH-009: レートリミット
- システム SHALL 100リクエスト/分/ユーザーのレートリミットを適用する
- WHEN レートリミットを超過する THEN システム SHALL 429エラーを返す

---

## 3. テナント・自社情報設定

### REQ-TENANT-001: テナント情報管理
- WHEN オーナー/管理者がテナント情報を更新する THEN システム SHALL 会社名・住所・電話番号・FAX・メール・Webサイト・銀行口座情報を保存する
- WHEN 適格請求書発行事業者登録番号（T+13桁）を入力する THEN システム SHALL 国税庁APIで有効性を非同期検証する

### REQ-TENANT-002: 業種テンプレート
- WHEN テナントが業種を選択する THEN システム SHALL 用語ラベル・デフォルト品目・帳票レイアウト設定を切り替える
- システム SHALL 6種の業種テンプレート（汎用 / IT / 建設 / デザイン / コンサルティング / 士業）を提供する

### REQ-TENANT-003: ロゴ・印影
- WHEN オーナー/管理者が画像をアップロードする THEN システム SHALL R2（MinIO）に保存し、帳票に反映する

### REQ-TENANT-004: 帳票採番フォーマット
- システム SHALL デフォルト採番フォーマット `{prefix}-{YYYY}{MM}-{SEQ}` を提供する
- WHEN テナントが採番フォーマットを変更する THEN 新規帳票 SHALL 新フォーマットで採番する

### REQ-TENANT-005: デフォルト設定
- システム SHALL デフォルト支払期日（30日）、デフォルト税率（10.00%）、会計年度開始月（4月）、タイムゾーン（Asia/Tokyo）を設定可能にする

---

## 4. 顧客管理

### REQ-CUSTOMER-001: 顧客CRUD
- WHEN ユーザー（owner〜sales）が有効な顧客情報を提供する THEN システム SHALL 顧客レコードを作成する
- WHEN ユーザーが顧客一覧を要求する THEN システム SHALL ページネーション・ソート・フィルタ付きの一覧を返す
- WHEN ユーザーが顧客を削除する THEN システム SHALL 論理削除（deleted_at設定）する
- システム SHALL 顧客タイプ（client / vendor / both）を管理する

### REQ-CUSTOMER-002: 顧客フィルタ・検索
- WHEN filter[q]パラメータが提供される THEN システム SHALL 会社名・カナで部分一致検索する
- WHEN filter[customer_type]が提供される THEN システム SHALL タイプで絞り込む
- WHEN filter[tags]が提供される THEN システム SHALL タグでOR検索する
- WHEN filter[has_overdue]=true THEN システム SHALL 支払遅延ありの顧客のみ返す（★入金回収）
- WHEN filter[credit_score_min/max]が提供される THEN システム SHALL 与信スコア範囲で絞り込む（★入金回収）
- WHEN filter[outstanding_min]が提供される THEN システム SHALL 未回収残高で絞り込む（★入金回収）

### REQ-CUSTOMER-003: 顧客担当者管理
- WHEN 顧客に担当者を追加する THEN システム SHALL 氏名・メール・部署・役職・主担当フラグ・請求先フラグを保存する
- システム SHALL 1顧客に複数の担当者を登録可能にする

### REQ-CUSTOMER-004: 適格請求書番号検証
- WHEN 顧客の適格請求書番号を登録する THEN システム SHALL 国税庁APIで非同期検証する（SolidQueueジョブ）
- WHEN 検証が完了する THEN システム SHALL invoice_number_verified と invoice_number_verified_at を更新する
- システム SHALL 国税庁APIへのリクエストを1回/秒以下に制限する

### REQ-CUSTOMER-005: 与信スコア（★入金回収特化）
- システム SHALL 0-100の与信スコアを以下のロジックで算出する:
  - 基本スコア: 50
  - 加点: 直近6ヶ月全期日内(+20) / 取引1年超(+15) / 早払い傾向(+10) / 累計100万円超(+5)
  - 減点: 直近3ヶ月30日超遅延(-30) / 直近6ヶ月14日超遅延2回(-20) / 遅延率30%超(-15) / 直近6ヶ月7日超遅延1回(-10) / 支払遅延傾向(-5)
- WHEN 毎日深夜2:00 THEN CreditScoreCalculationJob SHALL 全顧客の与信スコアを再計算する
- WHEN 与信スコアが大幅低下する THEN システム SHALL credit_score_dropped通知を生成する

### REQ-CUSTOMER-006: 顧客統計（★入金回収特化）
- WHEN 毎日深夜3:00 THEN CustomerStatsUpdateJob SHALL avg_payment_days / late_payment_rate / total_outstanding を再計算する
- システム SHALL 与信スコア履歴（credit_score_histories）を保存する

---

## 5. 品目マスタ

### REQ-PRODUCT-001: 品目CRUD
- WHEN ユーザーが品目を作成する THEN システム SHALL コード・名称・説明・単位・単価・税率・カテゴリを保存する
- システム SHALL 税率タイプ（standard 10% / reduced 8% / exempt 0%）を管理する
- WHEN テナント作成時 THEN システム SHALL 業種テンプレートに基づくデフォルト品目を作成する

### REQ-PRODUCT-002: 品目表示制御
- システム SHALL 品目の表示順（sort_order）と有効/無効（is_active）を管理する
- WHEN is_active=false THEN 品目 SHALL 帳票作成時の選択候補に表示されない

---

## 6. 案件管理

### REQ-PROJECT-001: 案件CRUD
- WHEN ユーザー（owner〜sales）が案件を作成する THEN システム SHALL テナント内ユニークな案件番号を自動採番する
- システム SHALL 案件名・ステータス・受注確度・見込み金額・原価・期間・タグ・カスタムフィールドを管理する

### REQ-PROJECT-002: ステータス遷移（ステートマシン）
- システム SHALL 以下のステータス遷移のみ許可する:
  - negotiation → won / lost
  - won → in_progress / cancelled
  - in_progress → delivered / cancelled
  - delivered → invoiced
  - invoiced → paid / partially_paid / overdue
  - partially_paid → paid / overdue
  - overdue → paid / partially_paid / bad_debt
  - bad_debt → paid
  - lost → negotiation
- WHEN 許可されていないステータス遷移を試みる THEN システム SHALL 422エラーを返す

### REQ-PROJECT-003: パイプライン
- WHEN ユーザーがパイプラインデータを要求する THEN システム SHALL ステータス別の件数・合計金額・案件リストを返す

---

## 7. 帳票管理

### REQ-DOC-001: 帳票CRUD
- システム SHALL 6種の帳票（estimate / purchase_order / order_confirmation / delivery_note / invoice / receipt）を管理する
- WHEN ユーザーが帳票を作成する THEN システム SHALL テナント内・タイプ内ユニークな帳票番号を自動採番する
- WHEN 帳票を作成/更新する THEN システム SHALL 金額をサーバーサイドで再計算する

### REQ-DOC-002: 金額計算ロジック
- システム SHALL 各明細行の金額を `(quantity × unit_price).floor` で算出する
- システム SHALL 税率別に一括で税額を算出する: `(subtotal × rate / 100).floor`（端数切捨て）
- システム SHALL tax_summary（税率別集計）を jsonb で保存する
- システム SHALL subtotal / tax_amount / total_amount / remaining_amount を自動計算する

### REQ-DOC-003: 帳票ステータス遷移
- システム SHALL 以下のステータス遷移を管理する:
  - draft → approved（承認フロー有効時） / sent（無効時）
  - approved → sent / draft（差し戻し）
  - sent → accepted / rejected（見積書のみ） / locked
  - cancelled（終了状態）
  - locked（変更不可。訂正は新バージョン作成）

### REQ-DOC-004: 帳票変換
- WHEN ユーザーが帳票変換を実行する THEN システム SHALL 元帳票の品目をコピーし、parent_document_id を設定する
- システム SHALL 以下の変換を許可する:
  - estimate → invoice / purchase_order
  - purchase_order → delivery_note / invoice
  - invoice → receipt（入金完了済みの場合のみ）

### REQ-DOC-005: PDF生成
- WHEN 帳票が確定する THEN PdfGenerationJob SHALL PDFを非同期生成しR2にアップロードする
- PDF SHALL インボイス対応（適格請求書番号・税率別集計を含む）する
- PDF SHALL 自社情報スナップショット・顧客情報スナップショットを使用する（発行時点の情報で固定）
- PDF生成時間 SHALL 3秒以下

### REQ-DOC-006: メール送信
- WHEN ユーザーが帳票を送信する THEN システム SHALL SendGridを通じてメールを送信する
- WHEN 送信が完了する THEN システム SHALL sent_at / sent_method を記録する

### REQ-DOC-007: 電子帳簿保存法対応
- WHEN 帳票がロックされる THEN システム SHALL locked_at にタイムスタンプを記録し、以降の変更を禁止する
- システム SHALL 日付・金額・取引先名での検索を可能にする
- システム SHALL 全操作をaudit_logsに記録する
- WHEN ロック済み帳票を訂正する場合 THEN システム SHALL 新バージョンを作成する（元帳票は変更不可）

### REQ-DOC-008: バージョン管理
- WHEN 帳票が更新される THEN システム SHALL document_versionsにスナップショットを保存する
- システム SHALL バージョン番号・変更者・変更理由を記録する

### REQ-DOC-009: 請求書入金ステータス（★入金回収特化）
- システム SHALL 請求書に入金ステータス（unpaid / partial / paid / overdue / bad_debt）を管理する
- WHEN 入金が記録される AND 入金額 < 請求額 THEN payment_status SHALL 'partial' になる
- WHEN 入金額 >= 請求額 THEN payment_status SHALL 'paid' になる
- WHEN 支払期日を超過する THEN InvoiceOverdueCheckJob SHALL payment_status を 'overdue' に更新する（毎日9:00実行）

### REQ-DOC-010: 帳票明細行
- システム SHALL 明細行タイプ（normal / subtotal / discount / section_header）を管理する
- WHEN 品目マスタから選択する THEN システム SHALL 品目のデフォルト値を自動入力する

---

## 8. 入金管理（★入金回収特化）

### REQ-PAYMENT-001: 手動入金記録
- WHEN ユーザー（owner / admin / accountant）が入金を記録する THEN システム SHALL payment_recordsを作成し、請求書のpaid_amount / remaining_amount / payment_statusを更新する
- WHEN 入金を取消す THEN システム SHALL payment_recordsを削除し、請求書の金額を再計算する

### REQ-PAYMENT-002: 銀行明細CSV取込
- WHEN ユーザーがCSVをアップロードする THEN システム SHALL Shift_JIS / UTF-8を自動判定しパースする
- システム SHALL 銀行別フォーマット（generic / mufg / smbc / mizuho / rakuten / jibun）を自動判定する
- WHEN 同一日付・金額・摘要の組み合わせが既存の場合 THEN システム SHALL 重複としてスキップする
- WHEN 取込完了後 THEN システム SHALL AiBankMatchJob を SolidQueue で非同期実行する

### REQ-PAYMENT-003: AI入金消込（★核心機能）
- システム SHALL 以下のステップでマッチングする:
  1. ルールベースフィルタリング: 金額完全一致 ± 1円の候補を抽出
  2. 名義マッチング: payer_nameを正規化し、顧客マスタと比較（Levenshtein距離 + 前方一致 + 部分一致）
  3. AI補完: confidence < 0.7 の候補をClaude API（Haiku）に送信
  4. 結果分類: confidence >= 0.90 → auto_matched / 0.70〜0.89 → needs_review / < 0.70 → unmatched
  5. 自動消込: auto_matchedのみ自動でpayment_records作成 + 請求書更新
- AI消込処理（50件） SHALL 15秒以下

### REQ-PAYMENT-004: AI消込確認UI
- WHEN AI消込が完了する THEN システム SHALL 自動消込済み・要確認・未マッチの3カテゴリで結果を表示する
- WHEN 要確認の候補について THEN システム SHALL AI候補（確信度付き）を表示し、ユーザーが確定/変更/スキップ可能にする

---

## 9. 督促管理（★入金回収特化）

### REQ-DUNNING-001: 督促ルールCRUD
- WHEN オーナー/管理者が督促ルールを作成する THEN システム SHALL トリガー日数・アクション種別・メールテンプレート・送信先・最大回数・間隔を保存する
- システム SHALL テンプレート変数（{{customer_name}} / {{document_number}} / {{total_amount}} / {{remaining_amount}} / {{due_date}} / {{overdue_days}} / {{company_name}} / {{bank_info}}）を提供する

### REQ-DUNNING-002: デフォルト督促シナリオ
- WHEN テナントが督促を有効化する THEN システム SHALL 4段階のデフォルト督促ルールを作成する:
  1. やさしいリマインド（1日後 / email）
  2. 通常督促（7日後 / email + 社内アラート）
  3. 強い督促（21日後 / email + 社内アラート）
  4. 最終通知（45日後 / email + 社内アラート）

### REQ-DUNNING-003: 自動督促実行
- WHEN 毎日10:00 THEN DunningExecutionJob SHALL 督促ルールに基づきメール送信 + dunning_logs記録する
- WHEN 督促メールを送信する THEN システム SHALL テンプレート変数を実際の値に置換して送信する
- WHEN 督促メール送信が失敗する THEN システム SHALL dunning_failed通知を生成する

### REQ-DUNNING-004: 督促履歴
- システム SHALL 全督促の履歴（送信先・件名・本文・ステータス・遅延日数・未回収額）をdunning_logsに記録する

---

## 10. 回収ダッシュボード（★入金回収特化）

### REQ-COLLECTION-001: 回収サマリー
- WHEN ユーザーが回収ダッシュボードにアクセスする THEN システム SHALL 以下のKPIを表示する:
  - 未回収合計金額
  - 遅延金額・件数
  - 遅延率
  - 今月の回収額・回収率
  - 平均回収日数（DSO）
  - 貸倒金額

### REQ-COLLECTION-002: 売掛金年齢表（エイジングレポート）
- システム SHALL 以下の期間区分で売掛金を分類する: 期限内 / 1-30日 / 31-60日 / 61-90日 / 90日超
- システム SHALL 顧客別のエイジングデータ（与信スコア付き）を提供する

### REQ-COLLECTION-003: 要注意取引先
- システム SHALL 与信スコアが低い / 遅延金額が大きい取引先を一覧表示する
- WHEN ユーザーが要注意取引先を選択する THEN システム SHALL 詳細表示および督促メール送信オプションを提供する

### REQ-COLLECTION-004: 回収トレンド
- システム SHALL 月次の請求額 vs 回収額のトレンドグラフデータを提供する

### REQ-COLLECTION-005: 入金予測
- システム SHALL 支払期日ベースの入金予定データを提供する

---

## 11. データ移行ウィザード（★移行爆速）

### REQ-IMPORT-001: 移行ジョブ管理
- システム SHALL import_jobsで移行ジョブのライフサイクルを管理する: pending → parsing → mapping → previewing → importing → completed / failed
- WHEN ユーザーがファイルをアップロードする THEN システム SHALL R2（MinIO）に保存し、pending状態のジョブを作成する

### REQ-IMPORT-002: ソースタイプ対応
- システム SHALL 以下のインポート形式に対応する:
  - board: CSVエクスポート（顧客・案件・見積書・請求書）
  - excel: .xlsx / .xls（AI自動カラム判定）
  - csv_generic: .csv（AI自動カラム判定）
- MVP Phase 2で freee / misoca / makeleaps に拡張

### REQ-IMPORT-003: AI自動マッピング（★核心機能）
- WHEN source_type=auto THEN システム SHALL:
  1. ファイルのヘッダー行を抽出
  2. 既知フォーマットのパターンとマッチング
  3. パターン不一致の場合 → Claude API（Haiku）にヘッダーのみ送信しマッピング提案を取得
  4. ユーザーにプレビュー + マッピング確認画面を表示
- WHEN 既知フォーマット（board等）の場合 THEN システム SHALL 事前定義のカラムマッピング（import_column_definitions）を使用する
- AIマッピングの確信度 SHALL バー表示（緑 >= 0.8 / 黄 0.5-0.79 / 赤 < 0.5）で表示する

### REQ-IMPORT-004: プレビュー・実行
- WHEN マッピングが確認される THEN システム SHALL 先頭10件のプレビューを生成する
- WHEN プレビューでエラーがある THEN システム SHALL エラー行をハイライトする
- WHEN ユーザーが実行を確定する THEN ImportExecutionJob SHALL SolidQueueで非同期実行する
- 移行処理（1000件） SHALL 30秒以下

### REQ-IMPORT-005: 結果レポート
- WHEN インポートが完了する THEN システム SHALL 成功件数 / スキップ件数 / エラー件数を表示する
- WHEN エラーがある THEN システム SHALL エラー詳細のCSVダウンロードを提供する
- WHEN 完了/失敗する THEN システム SHALL import_completed / import_failed 通知を生成する

---

## 12. メインダッシュボード

### REQ-DASHBOARD-001: KPIカード
- WHEN ユーザーがダッシュボードにアクセスする THEN システム SHALL 以下を表示する:
  - 今月売上（前月比）
  - 未回収金額（遅延件数）
  - 回収率（前月比）
  - 案件数（ステータス別）
- ダッシュボード表示 SHALL 1秒以下

### REQ-DASHBOARD-002: 入金回収アラート
- WHEN 遅延件数 > 0 THEN ダッシュボード SHALL 赤背景のアラートを表示する
- アラート SHALL 回収ダッシュボードへのリンクを含む

### REQ-DASHBOARD-003: 売上推移・入金予定
- システム SHALL 売上推移グラフ（棒+線）を表示する
- システム SHALL 直近の入金予定カレンダーを表示する

### REQ-DASHBOARD-004: 最近の取引
- システム SHALL 直近10件の帳票操作を表示する

### REQ-DASHBOARD-005: 期間切替
- システム SHALL 期間切替（今月 / 今四半期 / 今年度）を提供する

---

## 13. 通知

### REQ-NOTIFICATION-001: 通知生成
- システム SHALL 以下のイベントで通知を生成する:
  - invoice_due_soon: 支払期日3日前（owner, accountant宛）
  - invoice_overdue: 支払期日超過（owner, accountant宛）
  - payment_received: 入金消込完了（owner, accountant, 担当者宛）
  - dunning_sent: 督促メール送信（owner, accountant宛）
  - dunning_failed: 督促メール送信失敗（owner, admin宛）
  - import_completed / import_failed: データ移行完了/失敗（実行者宛）
  - document_approved: 帳票承認完了（作成者宛）
  - recurring_generated: 定期請求書生成（owner, accountant宛）
  - credit_score_dropped: 与信スコア低下（owner, accountant宛）
  - large_overdue_alert: 高額未回収アラート（owner宛）

### REQ-NOTIFICATION-002: 通知表示
- システム SHALL 未読/既読管理を提供する
- WHEN ユーザーが通知を確認する THEN システム SHALL is_read=true / read_at を更新する

---

## 14. 監査ログ

### REQ-AUDIT-001: 操作記録
- システム SHALL 全CUD操作（create / update / delete / send / lock / import / export / login）をaudit_logsに記録する
- システム SHALL 操作者・リソース種別・リソースID・変更差分・IPアドレス・User-Agentを記録する

---

## 15. 定期ジョブ

### REQ-JOB-001: 定期実行スケジュール
- InvoiceOverdueCheckJob: 毎日9:00 — 支払期日超過検出 + ステータス更新 + 通知
- DunningExecutionJob: 毎日10:00 — 督促ルール実行
- CreditScoreCalculationJob: 毎日2:00 — 与信スコア再計算
- RecurringInvoiceGenerationJob: 毎日6:00 — 定期請求書生成
- CustomerStatsUpdateJob: 毎日3:00 — 顧客統計再計算

---

## 16. プラン制限

### REQ-PLAN-001: プラン制限チェック
- システム SHALL 4プラン（free / starter / standard / professional）を提供する
- WHEN free THEN 制限: ユーザー1名 / 月5件帳票 / 顧客10社 / AI消込不可 / 自動督促不可 / 移行1回のみ
- WHEN starter THEN 制限: ユーザー3名 / 月50件帳票 / 顧客100社 / AI消込可 / 基本督促 / 移行無制限
- WHEN standard THEN 制限: ユーザー10名 / 無制限帳票 / 顧客500社 / AI消込可 / 全督促 / 移行無制限
- WHEN professional THEN 制限: ユーザー30名 / 無制限帳票 / 無制限顧客 / AI消込可 / 全督促 / 移行無制限
- WHEN 制限に達している状態で操作する THEN システム SHALL 制限超過エラーを返す

---

## 17. パフォーマンス要件

### REQ-PERF-001: レスポンス時間
- API応答時間（95パーセンタイル） SHALL 200ms以下
- PDF生成時間 SHALL 3秒以下
- AI消込処理（50件） SHALL 15秒以下
- AI見積提案 SHALL 5秒以下
- 移行処理（1000件） SHALL 30秒以下
- ダッシュボード表示 SHALL 1秒以下

---

## 18. セキュリティ要件

### REQ-SEC-001: セキュリティ対策
- システム SHALL TLS 1.3で通信を暗号化する
- システム SHALL bcrypt（cost=12）でパスワードをハッシュする
- システム SHALL Content-Security-Policyヘッダーを設定する（XSS対策）
- システム SHALL ActiveRecordのパラメータバインドを使用する（SQLインジェクション対策）
- システム SHALL R2署名付きURL（有効期限30分）でファイルアクセスを提供する

---

## Requirements Checklist
- [x] 全ユーザーロール（owner / admin / accountant / sales / member）を網羅
- [x] 正常系・エッジケース・エラーケースを網羅
- [x] 全要件がテスト可能・計測可能
- [x] 矛盾する要件なし
- [x] EARS形式で一貫して記述
