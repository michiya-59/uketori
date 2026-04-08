# ウケトリ 本番デプロイ手順書（AWS Lightsail 版）

> **作成日:** 2026-03-05
> **対象:** MVP (Phase 1) の本番デプロイ
> **所要時間目安:** 4〜6時間（初めての場合）
> **前提:** Mac で開発中。ターミナル操作の基本は分かる
>
> この手順書は**上から順番に**進めてください。順番を飛ばすと後の手順でエラーになります。

---

## 全体の流れ

```
Step 1:  コードの修正（デプロイ前に直すべき箇所）
Step 2:  GitHub にコードをプッシュ
Step 3:  データベースを用意する（Neon）
Step 4:  ファイル保存場所を用意する（Cloudflare R2）
Step 5:  サーバーを構築する（AWS Lightsail）        ← メインの作業
Step 6:  フロントエンドをデプロイする（Vercel）
Step 7:  ドメイン・SSL を設定する（Cloudflare + Let's Encrypt）
Step 8:  メール送信を設定する（Resend）
Step 9:  監視を設定する（Sentry + BetterStack）     ← 推奨
Step 10: バックアップを設定する                      ← 推奨
Step 11: 自動デプロイを設定する（GitHub Actions）    ← 推奨
Step 12: 最終確認
```

### この手順書で学べるスキル

| スキル | 説明 | 使う場面 |
|--------|------|---------|
| AWS (Lightsail) | Amazon のクラウドサーバー | どの会社でもほぼ必須 |
| Linux (Ubuntu) | サーバー OS の操作 | サーバー管理全般 |
| SSH | リモートサーバーへの安全な接続 | サーバー作業すべて |
| Docker | アプリをコンテナに入れて動かす | モダンな開発の必須スキル |
| Nginx | Web サーバー / リバースプロキシ | ほぼ全ての Web サービス |
| SSL/TLS (Let's Encrypt) | HTTPS 通信の暗号化 | セキュリティの基礎 |
| DNS | ドメイン名と IP アドレスの紐付け | Web サービス公開時 |
| CI/CD (GitHub Actions) | 自動テスト・自動デプロイ | チーム開発の標準 |
| cron | 定期タスクの自動実行 | バックアップ・バッチ処理 |
| 監視 (Sentry / BetterStack) | エラー検知・サーバーダウン通知 | 本番運用の必須スキル |

これらは**どの会社でも使われている基礎スキル**です。この手順を一度経験すれば、今後のエンジニア人生で必ず役に立ちます。

### 月額費用 (Phase 1: 0〜100ユーザー)

| サービス | 用途 | 月額 |
|---------|------|------|
| AWS Lightsail | Rails API サーバー | **$7 (約¥1,050)** Micro-1GB プラン |
| Neon | データベース | ¥0 (無料枠) |
| Vercel | フロントエンド | ¥0 (無料枠) |
| Cloudflare R2 | PDF・画像保存 | ¥0 (10GB無料) |
| Cloudflare | DNS + SSL | ¥0 |
| Resend | メール送信 | ¥0 (月3,000通無料) |
| Sentry | エラー監視 | ¥0 (月5,000イベント) |
| BetterStack | 外形監視 | ¥0 (5モニター) |
| Claude API (従量課金) | AI消込・AI見積等 | ¥200〜500 (利用量に依存) |
| **合計** | | **約¥1,250〜1,550** |

> **学習・開発フェーズ** では $5 の Nano-512MB プランでも動作します（Step 5-6 で設定するスワップ領域のおかげ）。有料ユーザーを迎える段階で $7 の Micro-1GB に上げてください。Lightsail のプラン変更は管理画面のスナップショット機能で簡単にできます。
>
> **Claude API の料金** はAI機能を使った回数に応じて発生します。AI消込・AI見積提案・AI移行マッピング等を使わなければ ¥0 です。

---

## Step 1: コードの修正

本番にデプロイする前に、いくつかのコードを修正する必要があります。
**すべての修正はローカル（自分のPC）で行います。**

---

### 1-1. Dockerfile の修正（これを直さないとデプロイが失敗します）

**なぜ？** 現在の Dockerfile は Apple Silicon (ARM) 用の設定になっていますが、Lightsail のサーバーは Intel (x86_64) です。このままだとサーバー起動時にクラッシュします。

**修正するファイル:** `api/Dockerfile` の5行目

```
変更前: ENV LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libjemalloc.so.2
変更後: ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2
```

---

### 1-2. 本番用のファイル保存設定・メール設定・SSL設定を追加

**なぜ？**

- PDF や画像をサーバーのディスクに保存すると容量を圧迫します。Cloudflare R2 に保存する設定が必要です
- 開発環境ではメールはコンソールに出力するだけですが、本番では実際に送信する必要があります
- Nginx が SSL を処理するため、ヘルスチェックの SSL リダイレクトをスキップする設定が必要です

**修正するファイル:** `api/config/environments/production.rb`

ファイルの末尾（最後の `end` の直前）に以下を追加:

```ruby
  # --- ファイル保存: Cloudflare R2 を使う ---
  config.active_storage.service = :amazon

  # --- メール送信: Resend (SMTP) を使う ---
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.default_url_options = {
    host: ENV.fetch("APP_HOST", "app.invoiceflow.jp"),
    protocol: "https"
  }
  config.action_mailer.smtp_settings = {
    address: "smtp.resend.com",
    port: 465,
    user_name: "resend",
    password: ENV["RESEND_API_KEY"],
    tls: true
  }

  # --- ヘルスチェックは SSL リダイレクトをスキップ ---
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }
```

---

### 1-3. Gemfile の修正

**なぜ？** メールサービスを SendGrid から Resend に変更するため不要な gem を削除し、エラー監視用の gem を追加します。

**修正するファイル:** `api/Gemfile`

```ruby
# この行を削除:
gem "sendgrid-ruby", require: false

# この2行を追加（例えば「# AI」セクションの下あたり）:
gem "sentry-ruby"
gem "sentry-rails"
```

修正後、ターミナルで以下を実行:

```bash
docker compose exec api bundle install
```

---

### 1-4. `.env.example` に不足している変数を追加

**なぜ？** コードの中で使われているのに `.env.example` に書かれていない環境変数があります。チームメンバーが増えたときに「何を設定すればいいか分からない」となるのを防ぎます。

**修正するファイル:** `.env.example`（プロジェクトルート）

末尾に以下を追加:

```bash
# --- フロントエンドURL（メール内リンク用） ---
FRONTEND_URL=http://localhost:4101

# --- CORS（APIへのアクセスを許可するドメイン） ---
CORS_ORIGINS=http://localhost:4101

# --- PDF署名URL用エンドポイント ---
MINIO_EXTERNAL_URL=http://localhost:9000

# --- ジョブキュー ---
SOLID_QUEUE_IN_PUMA=true

# --- 以下は本番でのみ必要 ---
# SECRET_KEY_BASE=
# RESEND_API_KEY=
# SENTRY_DSN=
# APP_HOST=app.invoiceflow.jp
```

---

### 1-4b. `.gitignore` の修正

**なぜ？** 現在の `.gitignore` は `.env` と `.env.local` しかカバーしていません。本番用の `.env.production` やステージング用の `.env.staging` が誤ってコミットされるリスクがあります。

**修正するファイル:** `.gitignore`（プロジェクトルート）

`# Environment` セクションを以下に書き換え:

```
# Environment
.env*
!.env.example
```

> **解説:** `.env*` は `.env` で始まるファイルをすべて無視します。`!.env.example` は「ただし `.env.example` は除外しない（= 追跡する）」という意味です。

---

### 1-5. 本番用 Docker Compose ファイルを作成

**なぜ？** 開発用の `docker-compose.yml` には DB や MinIO など開発専用のサービスが含まれています。本番では Rails API だけを動かす別のファイルが必要です。

**新規作成するファイル:** `docker-compose.production.yml`（プロジェクトルート）

```yaml
services:
  api:
    build:
      context: ./api
    ports:
      - "127.0.0.1:8080:8080"  # localhost のみ。外部から直接アクセスできないようにする
    env_file:
      - .env.production
    environment:
      - RAILS_ENV=production
      - PORT=8080
      - SOLID_QUEUE_IN_PUMA=true
    restart: always
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

> **なぜ `127.0.0.1:8080:8080` なの？**
> `"8080:8080"` だと、インターネットから直接 `http://IP:8080` でアクセスできてしまい、Nginx（と将来のSSL）を迂回されます。`127.0.0.1:` をつけることで、サーバー内部（Nginx）からのみアクセス可能になります。

---

### 1-6. Sentry 初期化ファイルを作成

**なぜ？** エラー監視サービス Sentry と Rails を接続するための設定ファイルです。

**新規作成するファイル:** `api/config/initializers/sentry.rb`

```ruby
Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.traces_sample_rate = 0.1
  config.environment = Rails.env
  config.enabled_environments = %w[production]
end
```

---

### 1-7. デプロイスクリプトを作成

**なぜ？** デプロイ時に毎回同じコマンドを打つのは面倒で、打ち間違いの原因にもなります。スクリプトにまとめておくと、自動デプロイ（Step 10）でも使えます。

**新規作成するファイル:** `deploy.sh`（プロジェクトルート）

```bash
#!/bin/bash
set -e

echo "=== ウケトリ デプロイ開始 ==="

cd /home/ubuntu/uketori

echo "1. 最新コードを取得..."
git pull origin main

echo "2. Docker イメージをビルド..."
docker compose -f docker-compose.production.yml build

echo "3. データベースマイグレーション（新イメージで実行）..."
docker compose -f docker-compose.production.yml run --rm -e RAILS_ENV=production api bin/rails db:migrate

echo "4. コンテナを再起動..."
docker compose -f docker-compose.production.yml up -d

echo "5. 古い Docker イメージを削除..."
docker image prune -f

echo "=== デプロイ完了 ==="
```

> **なぜマイグレーションが先？**
> 旧バージョンでは「再起動 → マイグレーション」の順でしたが、これだと**新しいコードが古いデータベース構造で動く瞬間**が発生し、エラーの原因になります。
> `docker compose run` を使うと、一時的なコンテナでマイグレーションだけを実行できます。マイグレーション完了後にコンテナを再起動するので安全です。

作成後、ターミナルで実行権限を付与します:

```bash
chmod +x deploy.sh
```

> **`chmod +x` とは？** ファイルに「実行してよい」という権限をつけるコマンドです。これがないと `bash deploy.sh` でしか実行できず、`./deploy.sh` で実行できません。

---

### 1-8. テスト確認

すべての修正が終わったら、テストが通ることを確認:

```bash
# バックエンドテスト
docker compose exec api bundle exec rspec

# フロントエンドビルド
docker compose exec web npm run build
```

両方とも成功すれば Step 1 完了です。

---

## Step 2: GitHub にコードをプッシュ

**なぜ？** Vercel（フロントエンド）は GitHub からコードを取得してデプロイします。Lightsail でもサーバーで `git clone` してコードを取得します。

---

### 2-1. GitHub でリポジトリを作成

1. https://github.com/new にアクセス
2. **Repository name:** `uketori` と入力
3. **Private** を選択（公開しない）
4. 「Create repository」をクリック
5. 表示されるページの URL をメモ（例: `https://github.com/あなたのユーザー名/uketori.git`）

---

### 2-2. ローカルからプッシュ

ターミナルで以下を**1行ずつ**実行:

```bash
# プロジェクトのルートディレクトリに移動
cd /Users/e0195/重要/uketori

# git を初期化（まだの場合）
git init

# リモートリポジトリを登録（URLは自分のものに置き換え）
git remote add origin https://github.com/あなたのユーザー名/uketori.git

# 全ファイルをステージング
git add .

# .env が含まれていないか確認（重要！）
git status
```

**確認ポイント:** `git status` の結果に `.env` が表示されていたら**絶対にコミットしないで**ください。`.gitignore` に `.env` が入っているか確認してください。`.env.example` は OK です。

```bash
# 初回コミット
git commit -m "Initial commit: ウケトリ MVP"

# main ブランチにプッシュ
git branch -M main
git push -u origin main
```

**確認:** GitHub のリポジトリページを開いてファイルが表示されていれば成功です。

---

## Step 3: データベースを用意する（Neon）

**Neon とは？** クラウド上の PostgreSQL データベースです。無料枠があり、サーバー管理が不要です。

---

### 3-1. アカウント作成

1. https://neon.tech にアクセス
2. 「Sign Up」→ GitHub アカウントでログイン（おすすめ）
3. ダッシュボードが表示されれば成功

---

### 3-2. プロジェクト作成

1. 「New Project」をクリック
2. 以下を入力:
   - **Project name:** `uketori`
   - **Database name:** `uketori_production`
   - **Region:** `Asia Pacific (Singapore)` ← 東京に一番近い
3. 「Create Project」をクリック

---

### 3-3. 接続情報をメモ

作成後、「Connection Details」が表示されます。

1. **Connection string** に表示されている文字列を**すべてコピー**してメモ

   例: `postgres://username:password@ep-xxxx-xxxx.ap-southeast-1.aws.neon.tech/uketori_production?sslmode=require`

2. この文字列が後で使う `DATABASE_URL` です

> **重要:** この文字列にはパスワードが含まれています。他人に見せないでください。

---

## Step 4: ファイル保存場所を用意する（Cloudflare R2）

**R2 とは？** PDF や画像を保存するクラウドストレージです。AWS S3 と互換性があり、10GB まで無料です。

---

### 4-1. Cloudflare アカウント作成

1. https://dash.cloudflare.com/sign-up にアクセス
2. メールアドレスとパスワードで登録
3. メール認証を完了

---

### 4-2. R2 を有効化

1. Cloudflare ダッシュボード左メニューの「R2 Object Storage」をクリック
2. 初回は「Get Started」→ 支払い情報の入力が求められる場合があります
   - **無料枠内なら課金されません**。クレジットカード登録は保険的なものです

---

### 4-3. バケット作成

1. 「Create bucket」をクリック
2. **Bucket name:** `uketori-production` と入力
3. **Location:** `Asia Pacific` を選択
4. 「Create bucket」をクリック

---

### 4-4. API トークン作成

R2 にプログラムからアクセスするための鍵を作ります。

1. R2 のページで右上の「Manage R2 API Tokens」をクリック
2. 「Create API Token」をクリック
3. 以下を設定:
   - **Token name:** `uketori-api`
   - **Permissions:** `Object Read & Write`
   - **Specify bucket(s):** `uketori-production` を選択
4. 「Create API Token」をクリック
5. 表示される以下の値を**必ずメモ**（二度と表示されません）:

| 名前 | 後で使う環境変数名 |
|------|-------------------|
| **Access Key ID** | `R2_ACCESS_KEY_ID` |
| **Secret Access Key** | `R2_SECRET_ACCESS_KEY` |

6. R2 のエンドポイント URL もメモ:
   - R2 ダッシュボードの「Settings」タブ → 「S3 API」のURL
   - 例: `https://xxxxxxxxx.r2.cloudflarestorage.com`
   - これが `R2_ENDPOINT` と `MINIO_EXTERNAL_URL` に使う値です

---

## Step 5: サーバーを構築する（AWS Lightsail）

**AWS Lightsail とは？** AWS（Amazon Web Services）の中で最もシンプルなサーバーサービスです。月額固定料金で仮想サーバー（VPS）を借りられます。普通の EC2 と違い、料金が固定なので安心です。

**このステップでやること:**

```
5-1.  AWS アカウント作成
5-2.  Lightsail インスタンス（サーバー）を作成
5-3.  静的 IP アドレスを割り当て
5-4.  ファイアウォール設定
5-5.  SSH でサーバーに接続
5-6.  サーバーの初期設定（Docker・Nginx のインストール）
5-7.  アプリケーションのデプロイ
5-8.  Nginx の設定（リバースプロキシ）
5-9.  データベースのセットアップ
5-10. 動作確認
```

---

### 5-1. AWS アカウント作成

1. https://aws.amazon.com/jp/ にアクセス
2. 「無料アカウントを作成」をクリック
3. メールアドレス、パスワード、アカウント名を入力
4. 連絡先情報を入力
5. クレジットカード情報を入力
6. 電話番号認証を完了
7. サポートプランは「ベーシック（無料）」を選択

---

### 5-2. Lightsail インスタンス作成

**「インスタンス」とは？** AWS での「サーバー1台」のことです。

1. https://lightsail.aws.amazon.com にアクセス
2. 右上のリージョンが **「東京」** になっていることを確認（なっていなければ変更）
3. 「インスタンスの作成」をクリック
4. 以下を設定:

| 設定項目 | 選択する値 |
|---------|-----------|
| インスタンスロケーション | 東京 (ap-northeast-1a) |
| プラットフォーム | Linux/Unix |
| 設計図 | 「OS のみ」→ **Ubuntu 22.04 LTS** |
| インスタンスプラン | **$7 USD / Micro-1GB**（1GB RAM, 2 vCPU, 40GB SSD, 2TB転送量）※学習段階なら $5 の Nano-512MB でも可 |
| インスタンス名 | `uketori-api` |

5. 「インスタンスの作成」をクリック

インスタンスの状態が「実行中」になるまで1〜2分待ちます。

> **プラン選びのポイント:**
>
> | プラン | RAM | 月額 | おすすめの場面 |
> |--------|-----|------|--------------|
> | Nano-512MB | 512MB | $5 | 学習・開発・動作確認（スワップ必須） |
> | **Micro-1GB** | 1GB | **$7** | **本番運用（推奨）** |
> | Small-2GB | 2GB | $12 | 50ユーザー超で検討 |
>
> 迷ったら **Micro-1GB ($7)** を選んでください。後からスナップショット機能でプラン変更できます。

---

### 5-3. 静的 IP アドレスの割り当て

**なぜ？** 静的 IP を割り当てないと、サーバーを再起動するたびに IP アドレスが変わってしまいます。ドメインと紐付けるためにも固定の IP が必要です。

1. Lightsail ダッシュボードの**左側メニュー**から「ネットワーキング」をクリック
   （※ インスタンスのネットワーキングタブではなく、左側メニューのほうです）
2. 「静的 IP の作成」をクリック
3. **アタッチ先:** `uketori-api` を選択
4. **静的 IP 名:** `uketori-api-ip`
5. 「作成」をクリック
6. 表示される **IP アドレス**（例: `13.230.xxx.xxx`）を**メモ**

> **重要:** この IP アドレスは後の手順で何度も使います。紛失しないようにしてください。
> 静的 IP はインスタンスにアタッチしている限り無料です。

---

### 5-4. ファイアウォール設定

**なぜ？** サーバーへの不正アクセスを防ぐため、必要なポートだけを開放します。

**「ポート」とは？** サーバーの「入り口の番号」です。22番は SSH 用、80番は HTTP 用、443番は HTTPS 用です。

1. Lightsail ダッシュボード → `uketori-api` をクリック → 「ネットワーキング」タブ
2. 「IPv4 ファイアウォール」セクションを確認

**デフォルトでは SSH(22) と HTTP(80) のみ開いています。HTTPS(443) は自分で追加する必要があります:**

3. 「ルールの追加」をクリック
4. **アプリケーション:** 「HTTPS」を選択 → 自動的にプロトコル TCP / ポート 443 が設定される
5. 「作成」をクリック

最終的に以下の3つのルールがあることを確認:

| アプリケーション | プロトコル | ポート |
|----------------|-----------|-------|
| SSH | TCP | 22 |
| HTTP | TCP | 80 |
| HTTPS | TCP | 443 ← **手動で追加** |

---

### 5-5. SSH でサーバーに接続

**SSH とは？** 自分の PC からリモートのサーバーに安全に接続して操作するための仕組みです。接続すると、サーバーのターミナルが自分の PC に表示されます。

#### 方法 A: Lightsail ブラウザコンソール（簡単だけど不便）

1. Lightsail ダッシュボード → `uketori-api` をクリック
2. 「SSH を使用して接続」をクリック
3. ブラウザ内にターミナルが表示されれば接続成功

> これでも作業できますが、コピー&ペーストがしづらいので方法 B がおすすめです。

#### 方法 B: 自分の PC のターミナルから接続（おすすめ）

**1. SSH キーをダウンロード:**

1. Lightsail ダッシュボード → 上部の「アカウント」→「SSH キー」タブ
2. 東京リージョンの「デフォルトキーのダウンロード」をクリック
3. `LightsailDefaultKey-ap-northeast-1.pem` というファイルがダウンロードされる

**2. ターミナルから接続:**

```bash
# ダウンロードしたキーのアクセス権限を設定（初回のみ）
# これをしないと「権限が広すぎる」というエラーになります
chmod 400 ~/Downloads/LightsailDefaultKey-ap-northeast-1.pem

# SSH で接続（IP アドレスは Step 5-3 でメモした自分のものに置き換え）
ssh -i ~/Downloads/LightsailDefaultKey-ap-northeast-1.pem ubuntu@あなたのIPアドレス
```

**3. 接続成功の確認:**

`ubuntu@ip-xxx-xxx-xxx-xxx:~$` のような表示が出たら接続成功です。

> **ヒント:** 毎回長いコマンドを打つのが面倒な場合、SSH 設定ファイルを作れます:
>
> ```bash
> # 自分の PC で実行（サーバーではなく）
> nano ~/.ssh/config
> ```
>
> 以下を貼り付けて保存:
>
> ```
> Host uketori
>     HostName あなたのIPアドレス
>     User ubuntu
>     IdentityFile ~/Downloads/LightsailDefaultKey-ap-northeast-1.pem
> ```
>
> これで次回から `ssh uketori` だけで接続できます。

---

### 5-6. サーバーの初期設定

**ここからは SSH で接続したサーバー内での作業です。**
プロンプト（画面の左端）が `ubuntu@ip-xxx:~$` になっていることを確認してください。

#### Docker のインストール

```bash
# 1. パッケージ一覧を最新にする（1〜2分かかります）
sudo apt update && sudo apt upgrade -y

# 2. Docker をインストール（公式インストールスクリプト）
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 3. Docker を sudo なしで使えるようにする
sudo usermod -aG docker ubuntu
```

**ここで一度ログアウトして再接続が必要です**（グループ変更を反映するため）:

```bash
# ログアウト
exit
```

自分の PC のターミナルに戻ったら、再度 SSH で接続:

```bash
ssh -i ~/Downloads/LightsailDefaultKey-ap-northeast-1.pem ubuntu@あなたのIPアドレス
```

#### Docker の動作確認

```bash
# バージョン確認（エラーにならなければ OK）
docker --version
docker compose version
```

#### Nginx のインストール

```bash
# Nginx をインストール
sudo apt install -y nginx

# 動作確認
sudo systemctl status nginx
```

`active (running)` と表示されれば OK です。`q` キーで表示を閉じます。

**確認:** 自分の PC のブラウザで `http://あなたのIPアドレス` にアクセスして「Welcome to nginx!」と表示されれば成功です。

#### Let's Encrypt（SSL 証明書ツール）のインストール

```bash
# certbot をインストール（Step 7 で使いますが、先にインストールしておきます）
# ※ apt 版は古いため、公式推奨の snap 版を使います
sudo snap install core && sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/local/bin/certbot

# インストール確認
certbot --version
```

#### スワップ領域の作成

**「スワップ」とは？** メモリ（RAM）が足りなくなったとき、ディスクの一部をメモリの代わりに使う仕組みです。Lightsail の Micro プラン（1GB）や Nano プラン（512MB）では、Docker + Nginx + Rails を動かすとメモリが不足することがあります。スワップを設定すると、メモリ不足でアプリがクラッシュするのを防げます。

```bash
# 2GB のスワップファイルを作成
sudo fallocate -l 2G /swapfile

# アクセス権限を設定（セキュリティのため）
sudo chmod 600 /swapfile

# スワップファイルとして初期化
sudo mkswap /swapfile

# スワップを有効化
sudo swapon /swapfile

# サーバー再起動後も自動で有効になるように設定
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

**確認:**

```bash
free -h
```

`Swap:` の行に `2.0Gi` と表示されれば成功です。

```
              total        used        free
Mem:          976Mi       200Mi       400Mi  ...
Swap:         2.0Gi          0B        2.0Gi
```

#### タイムゾーンの設定

**なぜ？** サーバーのデフォルトは UTC（協定世界時）です。ログの時刻や定期ジョブの実行時刻を日本時間に合わせるために、タイムゾーンを `Asia/Tokyo` に設定します。

```bash
# タイムゾーンを日本時間に設定
sudo timedatectl set-timezone Asia/Tokyo

# 確認
timedatectl
```

`Time zone: Asia/Tokyo (JST, +0900)` と表示されれば OK です。

#### OS の自動セキュリティ更新を有効化

**なぜ？** Ubuntu に脆弱性（セキュリティの穴）が見つかった場合、自動的にパッチを適用してくれます。手動で毎日 `apt update` するのは現実的ではないので、自動化しておきます。

```bash
# 自動更新パッケージをインストール
sudo apt install -y unattended-upgrades

# 自動更新を有効化
sudo dpkg-reconfigure -plow unattended-upgrades
```

「Automatically download and install stable updates?」と聞かれたら **`Yes`** を選択してください。

**確認:**

```bash
cat /etc/apt/apt.conf.d/20auto-upgrades
```

以下のように表示されれば OK です:

```
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

> 意味:「1日に1回、パッケージ一覧を更新し、セキュリティアップデートを自動適用する」

---

### 5-7. アプリケーションのデプロイ

**引き続き SSH で接続したサーバー内での作業です。**

#### リポジトリをクローン

**プライベートリポジトリの場合、まず Personal Access Token (PAT) を作成します:**

1. GitHub にログイン → 右上のアイコン → 「Settings」
2. 左メニュー最下部「Developer settings」→「Personal access tokens」→「Tokens (classic)」
3. 「Generate new token」→「Generate new token (classic)」
4. **Note:** `uketori-server-deploy`
5. **Expiration:** 「No expiration」（または長期間）
6. **Scopes:** `repo` にチェック
7. 「Generate token」→ 表示されるトークン（`ghp_` で始まる文字列）を**コピー**

> **重要:** GitHub はパスワードでの Git 操作を廃止しました。HTTPS で clone/pull するには PAT が必要です。

```bash
# ホームディレクトリにいることを確認
cd /home/ubuntu

# Git の認証情報を保存する設定（git pull のたびにPATを入力しなくて済むように）
git config --global credential.helper store

# GitHub からコードをダウンロード（URL は自分のものに置き換え）
git clone https://github.com/あなたのユーザー名/uketori.git
# ユーザー名を聞かれたら → GitHub のユーザー名を入力
# パスワードを聞かれたら → 上でコピーした PAT を貼り付け

# プロジェクトディレクトリに移動
cd uketori
```

> **確認:** `git pull origin main` を実行して、認証なしでコードが取得できれば OK です。
> これで GitHub Actions からの自動デプロイ（Step 10）でも `git pull` が正常に動作します。

#### 環境変数ファイルを作成

```bash
# .env.production ファイルを新規作成
nano .env.production
```

以下の内容を貼り付けます。**各値は自分のものに置き換えてください:**

```bash
# ===========================================
# ウケトリ 本番環境 環境変数
# ===========================================

# --- Rails ---
SECRET_KEY_BASE=ここにRails秘密キーを貼る
RAILS_LOG_LEVEL=info

# --- データベース ---
DATABASE_URL=ここにNeonの接続文字列を貼る

# --- JWT認証 ---
JWT_SECRET=ここにJWT秘密キーを貼る
JWT_EXPIRATION=900
JWT_REFRESH_EXPIRATION=604800

# --- AI (Claude API) ---
ANTHROPIC_API_KEY=ここにClaude APIキーを貼る

# --- ストレージ (Cloudflare R2) ---
R2_ENDPOINT=ここにR2エンドポイントURLを貼る
R2_ACCESS_KEY_ID=ここにR2アクセスキーを貼る
R2_SECRET_ACCESS_KEY=ここにR2シークレットキーを貼る
R2_BUCKET=uketori-production
MINIO_EXTERNAL_URL=R2_ENDPOINTと同じ値を貼る

# --- アプリケーション ---
CORS_ORIGINS=http://あなたのIPアドレス
FRONTEND_URL=http://あなたのIPアドレス
APP_HOST=あなたのIPアドレス
MAILER_FROM=noreply@example.com

# --- 国税庁API（適格請求書番号の検証に必要） ---
# https://www.invoice-kohyo.nta.go.jp/web-api/ で申請して取得
NTA_APP_ID=

# --- メール（Step 8 で本番の値に変更します） ---
RESEND_API_KEY=dummy

# --- エラー監視（Step 9 で本番の値に変更します） ---
SENTRY_DSN=
```

**秘密キーの生成方法（自分の PC のターミナルで実行）:**

```bash
# JWT 秘密キー（出力される長い文字列をコピー）
openssl rand -hex 64

# Rails 秘密キー（出力される長い文字列をコピー）
# ※ openssl で生成する方法を使います（Docker が起動していなくても OK）
openssl rand -hex 64
```

> **補足:** `rails secret` コマンドでも生成できますが、Docker コンテナの起動が必要です。
> `openssl rand -hex 64` なら Docker 不要で同等の秘密キーを生成できます。

**`nano` エディタの操作方法:**

| 操作 | キー |
|------|------|
| 貼り付け | Mac ターミナル: `Cmd+V`、他: `Ctrl+Shift+V` |
| 保存 | `Ctrl+O` → `Enter` |
| 終了 | `Ctrl+X` |

#### Docker イメージをビルドして起動

```bash
# プロジェクトディレクトリにいることを確認
cd /home/ubuntu/uketori

# ビルド（初回は5〜10分かかります。コーヒーでも飲んで待ちましょう）
docker compose -f docker-compose.production.yml build

# バックグラウンドで起動（-d をつけるとターミナルが解放されます）
docker compose -f docker-compose.production.yml up -d
```

#### 起動確認

```bash
# コンテナの状態を確認
docker compose -f docker-compose.production.yml ps
```

`STATUS` が `Up` になっていれば成功です。

```bash
# エラーの場合はログを確認
docker compose -f docker-compose.production.yml logs --tail 50
```

---

### 5-8. Nginx の設定（リバースプロキシ）

**「リバースプロキシ」とは？** 外部からのアクセス（80番ポート）を受け取って、内部の Docker コンテナ（8080番ポート）に転送する仕組みです。

```
ユーザー → [80] Nginx → [8080] Docker (Rails)
```

#### Nginx 設定ファイルを作成

```bash
# デフォルト設定を無効化
sudo rm /etc/nginx/sites-enabled/default

# 新しい設定ファイルを作成
sudo nano /etc/nginx/sites-available/uketori-api
```

以下の内容を貼り付け:

```nginx
server {
    listen 80;
    server_name _;

    # ファイルアップロードの上限サイズ（PDFや画像用に20MBに設定）
    client_max_body_size 20M;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

> **補足:** `proxy_set_header X-Forwarded-Proto https;` は Rails に「HTTPS でアクセスされている」と伝える設定です。Step 7 で実際に HTTPS を設定するまでの暫定措置です。

```bash
# 設定を有効化（シンボリックリンクを作成）
sudo ln -s /etc/nginx/sites-available/uketori-api /etc/nginx/sites-enabled/

# 設定ファイルに文法エラーがないか確認
sudo nginx -t
```

`syntax is ok` と `test is successful` が表示されれば OK です。

```bash
# Nginx を再読み込み（設定を反映）
sudo systemctl reload nginx
```

---

### 5-9. データベースのセットアップ

```bash
cd /home/ubuntu/uketori

# テーブルを作成（マイグレーション実行）
docker compose -f docker-compose.production.yml exec -T api bin/rails db:migrate

# SolidQueue / SolidCache のテーブルを作成
docker compose -f docker-compose.production.yml exec -T api bin/rails db:prepare

# 初期データを投入（業種テンプレート等）
docker compose -f docker-compose.production.yml exec -T api bin/rails db:seed
```

> **エラーが出た場合:** `DATABASE_URL` が正しいか `.env.production` を確認してください。
> Neon の接続文字列は `?sslmode=require` が末尾に必要です。

#### 初期データの確認

```bash
docker compose -f docker-compose.production.yml exec -T api bin/rails runner \
  "puts '業種テンプレート: ' + IndustryTemplate.count.to_s + '件'; puts 'ユーザー: ' + User.count.to_s + '件'"
```

| 期待される結果 | 意味 |
|--------------|------|
| `業種テンプレート: 6件` | 6つの業種テンプレートが登録された |
| `ユーザー: 1件` | シードユーザーが作成された |

#### 本番用管理者アカウントの作成

シードデータには開発用のアカウントが含まれていますが、**本番用の自分のアカウント**を作成します:

```bash
docker compose -f docker-compose.production.yml exec api bin/rails console
```

Rails コンソールが起動したら、以下を**自分の情報に書き換えて**入力:

```ruby
# テナント（自社）を確認
tenant = Tenant.first
puts "テナント: #{tenant.name}"

# 本番管理者ユーザーを作成（メールアドレスとパスワードは自分のものに変更！）
user = User.create!(
  tenant: tenant,
  email: "あなたのメールアドレス@example.com",
  password: "最低8文字の安全なパスワード",
  password_confirmation: "同じパスワードをもう一度",
  name: "あなたの名前",
  role: "owner"
)
puts "作成完了: #{user.email} (#{user.role})"
```

> **重要:** 作成後、上のメールアドレスとパスワードでログインできることを確認してください。
> 確認できたら `exit` でコンソールを終了します。

```ruby
exit
```

#### SolidQueue（定期ジョブ）の動作確認

```bash
docker compose -f docker-compose.production.yml exec -T api bin/rails runner \
  "tasks = SolidQueue::RecurringTask.all; puts \"登録済み定期ジョブ: #{tasks.count}件\"; tasks.each { |t| puts \"  - #{t.key}: #{t.class_name || t.command&.first(50)}\" }"
```

以下のような出力が表示されれば正常に動作しています:

```
登録済み定期ジョブ: 6件
  - clear_solid_queue_finished_jobs: SolidQueue::Job.clear_finished_in_batche...
  - invoice_overdue_check: InvoiceOverdueCheckJob
  - dunning_execution: DunningExecutionJob
  - credit_score_calculation: CreditScoreCalculationJob
  - customer_stats_update: CustomerStatsUpdateJob
  - recurring_invoice_generation: RecurringInvoiceGenerationJob
```

> **0件の場合:** `SOLID_QUEUE_IN_PUMA=true` が `.env.production` に設定されているか確認し、コンテナを再起動してください:
>
> ```bash
> docker compose -f docker-compose.production.yml restart
> ```
>
> 再起動後、1〜2分待ってから再度確認してください。

---

### 5-10. 動作確認

```bash
# サーバー内から API にアクセス
curl http://localhost:8080/up
```

何らかの応答があれば、Docker 内の Rails は動いています。

次に、**自分の PC のブラウザ**で:

```
http://あなたのIPアドレス/up
```

にアクセスしてください。応答があれば、Nginx → Docker → Rails の経路が正常に動作しています。

> **うまくいかない場合のチェックリスト:**
>
> | 確認項目 | コマンド |
> |---------|---------|
> | Docker コンテナが動いているか | `docker compose -f docker-compose.production.yml ps` |
> | コンテナのログにエラーがないか | `docker compose -f docker-compose.production.yml logs --tail 50` |
> | Nginx が動いているか | `sudo systemctl status nginx` |
> | Nginx のエラーログ | `sudo tail -50 /var/log/nginx/error.log` |
> | ファイアウォールで 80 番が開いているか | Lightsail ダッシュボードで確認 |

---

## Step 6: フロントエンドをデプロイする（Vercel）

**Vercel とは？** Next.js を作った会社のホスティングサービスです。GitHub にプッシュするだけで自動デプロイされます。

---

### 6-1. アカウント作成

1. https://vercel.com にアクセス
2. 「Sign Up」→ **「Continue with GitHub」** を選択
3. GitHub との連携を許可

---

### 6-2. プロジェクトをインポート

1. ダッシュボードで「Add New...」→「Project」をクリック
2. 「Import Git Repository」から `uketori` リポジトリを選択
3. 以下を設定:

| 設定項目 | 値 |
|---------|-----|
| **Project Name** | `uketori-web` |
| **Framework Preset** | `Next.js`（自動検出されるはず） |
| **Root Directory** | 「Edit」をクリック → `web` と入力 ← **重要！忘れると失敗します** |

---

### 6-3. 環境変数を設定

同じ画面の「Environment Variables」セクションで:

| Key | Value |
|-----|-------|
| `NEXT_PUBLIC_API_URL` | `http://あなたのIPアドレス`（後でドメインに変更します） |

---

### 6-4. デプロイ

「Deploy」ボタンをクリック。2〜3分でデプロイが完了します。

---

### 6-5. 動作確認

デプロイ完了後、表示される URL（例: `https://uketori-web.vercel.app`）にアクセス。
ログイン画面が表示されれば成功です。

> **注意: この時点ではログイン等の API 通信はまだ動きません。**
> Vercel は HTTPS（`https://...vercel.app`）ですが、API はまだ HTTP（`http://IP`）です。
> ブラウザは「HTTPS のページから HTTP の API を呼ぶ」ことを**混合コンテンツ (Mixed Content)**としてブロックします。
> **Step 7（ドメイン・SSL）を完了すると、API も HTTPS になり、全機能が動作するようになります。**
> 今の時点では「ログイン画面が表示されること」だけ確認すれば OK です。

> **CORS エラーが出る場合:**
> サーバーに SSH 接続して `.env.production` の `CORS_ORIGINS` を Vercel の URL に更新します:
>
> ```bash
> ssh uketori  # または ssh -i ... ubuntu@IP
> cd /home/ubuntu/uketori
> nano .env.production
> ```
>
> `CORS_ORIGINS` の値を変更:
> ```
> CORS_ORIGINS=https://uketori-web.vercel.app
> FRONTEND_URL=https://uketori-web.vercel.app
> ```
>
> 保存後、コンテナを再起動:
> ```bash
> docker compose -f docker-compose.production.yml up -d
> ```

---

## Step 7: ドメイン・SSL を設定する（Cloudflare + Let's Encrypt）

**なぜ？**

- 独自ドメイン（`invoiceflow.jp`）を使うと信頼性が上がります
- SSL（HTTPS）がないと「安全ではありません」という警告がブラウザに表示されます
- **Let's Encrypt** を使えば SSL 証明書が**無料**で取得できます

> **まだドメインが不要な場合:** この Step はスキップして Step 8 に進んでも OK です。後からいつでも設定できます。ただし、本番公開前には必ず設定してください。

---

### 7-1. ドメイン構成の確認

**使用するドメイン:** `invoiceflow.jp`（お名前.com で取得済み）

このドメインで以下のように使い分けます:

| URL | 用途 | 向き先 |
|-----|------|--------|
| `api.invoiceflow.jp` | Rails API サーバー | Lightsail（静的 IP） |
| `app.invoiceflow.jp` | フロントエンド（Next.js） | Vercel |
| `invoiceflow.jp` | （将来）LP・公式サイト | 必要になった時に設定 |

---

### 7-2. Cloudflare にドメインを追加

**なぜ Cloudflare を使うの？** DNS（ドメインと IP の紐付け）の管理が無料で、画面も分かりやすいからです。

1. https://dash.cloudflare.com にログイン
2. 「Add a Site」をクリック
3. ドメイン名: `invoiceflow.jp` を入力
4. **Free プラン**を選択 → 「Continue」
5. 「Nameservers」ページに2つのネームサーバーが表示される → **メモ**

---

### 7-3. お名前.com でネームサーバーを変更する

**「ネームサーバー」とは？** 「このドメインの DNS 情報はどこにあるか」を指定するものです。Cloudflare で DNS を管理するために、ドメインのネームサーバーを Cloudflare のものに切り替えます。

**お名前.com での操作手順:**

1. https://navi.onamae.com にログイン
2. 上部メニュー「ドメイン」→「ドメイン機能一覧」をクリック
3. 「ネームサーバーの変更」をクリック
4. `invoiceflow.jp` を選択
5. 「他のネームサーバーを利用」タブをクリック
6. ネームサーバー情報を入力:

| 項目 | 値（Step 7-2 でメモした Cloudflare のネームサーバーを入力） |
|------|--------------------------------------------------------|
| ネームサーバー1 | 例: `anna.ns.cloudflare.com` |
| ネームサーバー2 | 例: `bob.ns.cloudflare.com` |

7. 「確認画面へ進む」→「設定する」をクリック

> **注意:** お名前.com は「転出を防ぐため」の確認画面が出ることがあります。ネームサーバーの変更はドメインの転出（移管）ではないので、安心して進めてください。
>
> **反映に最大24時間かかります。** 通常は数分〜数時間で反映されます。
> Cloudflare ダッシュボードに戻り、ステータスが **「Active」** になれば反映完了です。

---

### 7-4. DNS レコードを設定

**「DNS レコード」とは？** 「このドメイン名は、この IP アドレスのサーバーのことだよ」という対応表です。

Cloudflare ダッシュボード → 「DNS」→「Records」で以下を追加:

#### API 用（Lightsail サーバーに向ける）

| Type | Name | Content | Proxy status |
|------|------|---------|-------------|
| **A** | `api` | `あなたのLightsail静的IP` | **DNS only (灰色の雲)** |

> **重要:** Proxy status は **「DNS only」(灰色の雲)** にしてください。「Proxied」(オレンジの雲) にすると Let's Encrypt の証明書取得に失敗する場合があります。

#### フロントエンド用（Vercel に向ける）

| Type | Name | Content | Proxy status |
|------|------|---------|-------------|
| **CNAME** | `app` | `cname.vercel-dns.com` | **DNS only (灰色の雲)** |

**確認:** 数分後に以下のコマンドで DNS が反映されたか確認できます:

```bash
# 自分の PC で実行
nslookup api.invoiceflow.jp
nslookup app.invoiceflow.jp
```

IP アドレスやホスト名が正しく表示されれば OK です。

---

### 7-5. SSL 証明書を取得する（Let's Encrypt）

**「SSL 証明書」とは？** HTTPS 通信を暗号化するための電子証明書です。Let's Encrypt を使えば無料で取得できます。

**SSH でサーバーに接続して作業します:**

```bash
ssh uketori  # または ssh -i ... ubuntu@IP
```

#### Nginx の設定を更新（ドメイン名を指定）

```bash
sudo nano /etc/nginx/sites-available/uketori-api
```

`server_name _;` の行を自分のドメインに変更:

```nginx
server {
    listen 80;
    server_name api.invoiceflow.jp;  # ← ここを変更

    client_max_body_size 20M;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

```bash
# 設定を反映
sudo nginx -t && sudo systemctl reload nginx
```

#### certbot で SSL 証明書を取得

```bash
# certbot を実行（ドメインは自分のものに置き換え）
sudo certbot --nginx -d api.invoiceflow.jp
```

**質問への回答:**

| 質問 | 回答 |
|------|------|
| Enter email address | 自分のメールアドレスを入力 |
| Terms of Service | `Y` を入力 |
| Share email with EFF | `N` でOK |

certbot が自動的に:
1. SSL 証明書を取得
2. Nginx の設定を HTTPS 対応に書き換え
3. HTTP → HTTPS のリダイレクトを設定

してくれます。

#### 確認

自分の PC のブラウザで `https://api.invoiceflow.jp/up` にアクセス。
鍵マーク（HTTPS）が表示され、応答があれば成功です。

---

### 7-6. SSL 証明書の自動更新を設定

Let's Encrypt の証明書は **90日間** で期限切れになります。自動更新を設定しておかないと、90日後に突然サイトが使えなくなります。

```bash
# 自動更新のテスト（実際には更新しない。テストだけ）
sudo certbot renew --dry-run
```

`Congratulations, all simulated renewals succeeded` と表示されれば OK です。

snap 版 certbot は自動的に更新タイマーを設定するので、通常は追加作業不要です:

```bash
# 自動更新タイマーの確認
sudo systemctl list-timers | grep certbot
```

`snap.certbot.renew.timer` が表示されていれば、自動的に証明書が更新されます（1日2回チェック）。

---

### 7-7. Vercel にカスタムドメインを設定

1. Vercel ダッシュボード → プロジェクト → 「Settings」→「Domains」
2. `app.invoiceflow.jp` を入力 →「Add」
3. 検証が完了するまで数分待つ

---

### 7-8. 環境変数をドメインに合わせて更新

#### サーバー側（Lightsail）

```bash
ssh uketori  # サーバーに接続
cd /home/ubuntu/uketori
nano .env.production
```

以下の値を更新:

```bash
CORS_ORIGINS=https://app.invoiceflow.jp
FRONTEND_URL=https://app.invoiceflow.jp
APP_HOST=app.invoiceflow.jp
MAILER_FROM=noreply@invoiceflow.jp
```

保存して、コンテナを再起動:

```bash
docker compose -f docker-compose.production.yml up -d
```

#### Vercel 側

1. Vercel ダッシュボード → プロジェクト → 「Settings」→「Environment Variables」
2. `NEXT_PUBLIC_API_URL` を `https://api.invoiceflow.jp` に変更
3. 「Deployments」タブ → 最新のデプロイの「...」→「Redeploy」をクリック

---

### 7-9. 動作確認

- `https://api.invoiceflow.jp/up` → API が応答するか
- `https://app.invoiceflow.jp` → ログイン画面が表示されるか
- ブラウザのアドレスバーに鍵マーク（HTTPS）が表示されるか

---

## Step 8: メール送信を設定する（Resend）

**なぜ？** パスワードリセット、ユーザー招待、帳票送信、督促メールを実際に送信するために必要です。

---

### 8-1. アカウント作成

1. https://resend.com にアクセス
2. 「Get Started」→ GitHub でログイン
3. ダッシュボードが表示されれば OK

---

### 8-2. API キーを取得

1. 左メニュー「API Keys」をクリック
2. 「Create API Key」をクリック
3. **Name:** `uketori-production`
4. **Permission:** `Sending access`
5. 「Create」をクリック
6. 表示されたキー（`re_` で始まる文字列）を**コピーしてメモ**

---

### 8-3. 送信ドメインを認証

**なぜ？** ドメイン認証をしないと、送信したメールが迷惑メールに振り分けられます。

1. 左メニュー「Domains」→「Add Domain」
2. ドメイン名: `invoiceflow.jp` を入力
3. 表示される DNS レコードを Cloudflare に追加:

   Cloudflare ダッシュボード → 「DNS」→「Records」で、Resend が指示する**すべてのレコード**を追加:

   - **SPF レコード** (TXT タイプ) — 「このドメインからメールを送っていいサーバー」を指定
   - **DKIM レコード** (TXT タイプ) — メールの改ざんを検知する電子署名
   - **DMARC レコード** (TXT タイプ) — SPF/DKIM の検証失敗時の処理ポリシー

4. Resend のページに戻り「Verify」をクリック
5. ステータスが **「Verified」** になれば成功（数分〜数十分かかることがあります）

---

### 8-4. サーバーの環境変数を更新

```bash
ssh uketori
cd /home/ubuntu/uketori
nano .env.production
```

`RESEND_API_KEY` の値を更新:

```bash
RESEND_API_KEY=re_xxxxxxxxxx
```

保存して、コンテナを再起動:

```bash
docker compose -f docker-compose.production.yml up -d
```

---

### 8-5. メール送信テスト

アプリにアクセスして、パスワードリセットを試す:

1. ログイン画面 → 「パスワードを忘れた方」
2. メールアドレスを入力して送信
3. メールが届けば成功

> メールが届かない場合、Resend ダッシュボードの「Logs」でエラーを確認してください。

---

## Step 9: 監視を設定する（Sentry + BetterStack） ← 推奨

**なぜ？** 本番でエラーが起きたとき、ユーザーからの報告を待たずに気づけます。2つの監視を設定します:

| 監視ツール | 役割 | 無料枠 |
|-----------|------|--------|
| **Sentry** | エラー監視（アプリ内部のエラーを検知） | 月 5,000 イベント |
| **BetterStack** | 外形監視（サーバーがダウンしたら通知） | 5 モニター |

> **エラー監視 vs 外形監視の違い:**
> - **エラー監視（Sentry）:** アプリが動いているけど内部でエラーが起きているときに検知
> - **外形監視（BetterStack）:** アプリ自体がダウンして応答しなくなったときに検知
>
> 両方設定することで、あらゆる障害を漏れなく検知できます。

---

### 9-1. アカウント作成

1. https://sentry.io にアクセス
2. 「Get Started」→ GitHub でログイン

---

### 9-2. プロジェクト作成

1. 「Create Project」をクリック
2. プラットフォーム: **「Ruby」→「Rails」** を選択
3. **Project name:** `uketori-api`
4. 「Create Project」をクリック
5. 表示される **DSN**（`https://xxxx@oXXXX.ingest.sentry.io/YYYY` という形式）を**メモ**

---

### 9-3. サーバーの環境変数を更新

```bash
ssh uketori
cd /home/ubuntu/uketori
nano .env.production
```

`SENTRY_DSN` の値を更新:

```bash
SENTRY_DSN=https://xxxx@oXXXX.ingest.sentry.io/YYYY
```

保存して、コンテナを再ビルド＆再起動（Sentry の gem を含むため）:

```bash
docker compose -f docker-compose.production.yml build
docker compose -f docker-compose.production.yml up -d
```

---

### 9-4. BetterStack（外形監視）のアカウント作成

1. https://betterstack.com にアクセス
2. 「Get Started for Free」→ GitHub でログイン
3. ダッシュボードが表示されれば OK

---

### 9-5. モニターを作成

1. 左メニュー「Monitors」→「Create monitor」をクリック
2. 以下を設定:

| 設定項目 | 値 |
|---------|-----|
| **Monitor type** | HTTP(s) |
| **URL to monitor** | `https://api.invoiceflow.jp/up` |
| **Check frequency** | `Every 3 minutes`（3分ごとにチェック） |
| **Monitor name** | `Uketori API` |

3. 「Create monitor」をクリック

---

### 9-6. アラート通知先を設定

**「サーバーが落ちたらどこに通知するか」の設定です。**

1. 左メニュー「Who to alert」→「Escalation policies」
2. デフォルトのポリシーをクリック
3. **通知先**にメールアドレスが登録されていることを確認
4. 必要に応じて Slack や Discord の通知も追加可能

> **無料プランでは** メール通知のみ利用可能です。十分です。

---

### 9-7. 動作確認

BetterStack のダッシュボードで、モニターのステータスが **「Up」（緑色）** になっていれば成功です。

> **テスト方法:** サーバーで `docker compose -f docker-compose.production.yml down` を実行すると、数分後に BetterStack から「ダウン」のメール通知が届きます。確認後、すぐに `docker compose -f docker-compose.production.yml up -d` で復旧してください。

---

## Step 10: バックアップを設定する ← 推奨

**なぜ？** データベースが壊れたり、誤操作でデータを削除してしまった場合に復元するためです。Neon にも自動バックアップ機能がありますが、**自分でもバックアップを持っておく**ことで安心感が格段に上がります。

---

### 10-1. Neon の自動バックアップを確認

Neon は無料プランでも過去 **7日間** のバックアップを自動で保持しています。

1. https://console.neon.tech にログイン
2. プロジェクト `uketori` を選択
3. 左メニュー「Branches」をクリック
4. `main` ブランチが表示されていれば OK（これが自動バックアップの単位です）

> **Neon のバックアップだけで大丈夫？** 無料プランでは「7日前まで」しか戻れません。7日以上前のデータが必要になるケース（例: 月末に先月のデータが消えたことに気づく）に備えて、次の手順で定期バックアップも設定します。

---

### 10-2. サーバーで定期バックアップスクリプトを作成

**SSH でサーバーに接続して作業します:**

```bash
ssh uketori
```

#### バックアップ用のディレクトリを作成

```bash
mkdir -p /home/ubuntu/backups
```

#### バックアップスクリプトを作成

```bash
nano /home/ubuntu/backup.sh
```

以下の内容を貼り付け:

```bash
#!/bin/bash
set -e

BACKUP_DIR="/home/ubuntu/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
FILENAME="uketori_${TIMESTAMP}.sql.gz"

echo "=== バックアップ開始: ${FILENAME} ==="

# Docker コンテナ内から DATABASE_URL を取得してダンプ
docker compose -f /home/ubuntu/uketori/docker-compose.production.yml exec -T api \
  bin/rails runner "puts ENV['DATABASE_URL']" > /tmp/db_url.txt

DB_URL=$(cat /tmp/db_url.txt | tail -1)
rm /tmp/db_url.txt

# pg_dump を Docker コンテナ内で実行して圧縮
docker compose -f /home/ubuntu/uketori/docker-compose.production.yml exec -T api \
  bash -c "apt-get -qq install -y postgresql-client > /dev/null 2>&1 || true; pg_dump '${DB_URL}' --no-owner --no-privileges" \
  | gzip > "${BACKUP_DIR}/${FILENAME}"

# 30日以上前のバックアップを削除
find "${BACKUP_DIR}" -name "uketori_*.sql.gz" -mtime +30 -delete

# ファイルサイズを表示
FILE_SIZE=$(du -h "${BACKUP_DIR}/${FILENAME}" | cut -f1)
echo "=== バックアップ完了: ${FILENAME} (${FILE_SIZE}) ==="
```

保存してエディタを閉じたら、実行権限を付与:

```bash
chmod +x /home/ubuntu/backup.sh
```

#### テスト実行

```bash
bash /home/ubuntu/backup.sh
```

`バックアップ完了` と表示され、`/home/ubuntu/backups/` にファイルが作成されれば成功です。

```bash
# 確認
ls -la /home/ubuntu/backups/
```

---

### 10-3. 自動実行を設定（cron）

**「cron」とは？** 指定した時刻にコマンドを自動実行する Linux の仕組みです。

```bash
# cron の設定を開く
crontab -e
```

初回は「どのエディタを使うか」聞かれます。**`1` (nano)** を選んでください。

ファイルの **一番下** に以下の1行を追加:

```
0 3 * * * /home/ubuntu/backup.sh >> /home/ubuntu/backups/backup.log 2>&1
```

> **この行の意味:**
>
> | 部分 | 意味 |
> |------|------|
> | `0 3 * * *` | 毎日 午前3時0分 に実行 |
> | `/home/ubuntu/backup.sh` | 実行するスクリプト |
> | `>> /home/ubuntu/backups/backup.log` | ログを追記保存 |
> | `2>&1` | エラーも同じファイルに記録 |

保存してエディタを閉じます（`Ctrl+O` → `Enter` → `Ctrl+X`）。

```bash
# 設定が保存されたか確認
crontab -l
```

上で追加した行が表示されれば OK です。

> **バックアップの確認方法:** 翌日以降に以下のコマンドで確認できます:
>
> ```bash
> ls -la /home/ubuntu/backups/
> cat /home/ubuntu/backups/backup.log
> ```

---

### 10-4. バックアップからの復元方法（緊急時用メモ）

万が一データを復元する必要が出た場合の手順です。**今は実行しないでください。**メモとして残しておきます。

```bash
# 1. 復元したいバックアップファイルを選ぶ
ls /home/ubuntu/backups/

# 2. 圧縮を解凍して復元（※ 現在のデータは上書きされます！）
gunzip -c /home/ubuntu/backups/uketori_20260406_030000.sql.gz | \
  docker compose -f /home/ubuntu/uketori/docker-compose.production.yml exec -T api \
  bash -c "psql \$(bin/rails runner \"puts ENV['DATABASE_URL']\" | tail -1)"
```

> **注意:** 復元すると現在のデータが消えます。必ず復元前に「今のデータ」のバックアップを取ってから実行してください。

---

## Step 11: 自動デプロイを設定する（GitHub Actions + SSH） ← 推奨

**なぜ？** 毎回サーバーに SSH してデプロイコマンドを打つのは面倒です。`git push` するだけで自動的にテスト → デプロイが実行されるようにします。

---

### 11-1. デプロイ用 SSH キーを作成

**自分の PC のターミナルで実行します（サーバーではなく）:**

```bash
# GitHub Actions がサーバーに接続するための専用キーを作成
ssh-keygen -t ed25519 -f ~/.ssh/uketori-deploy -C "github-actions-deploy" -N ""
```

これで2つのファイルが作られます:
- `~/.ssh/uketori-deploy` — 秘密鍵（GitHub に登録する）
- `~/.ssh/uketori-deploy.pub` — 公開鍵（サーバーに登録する）

#### 公開鍵をサーバーに登録

```bash
# 公開鍵の内容を表示してコピー
cat ~/.ssh/uketori-deploy.pub
```

表示された文字列をコピーして、サーバーに登録:

```bash
ssh uketori

# 公開鍵を authorized_keys に追加（引用符の中に公開鍵を貼り付け）
echo 'ここにコピーした公開鍵を貼り付け' >> ~/.ssh/authorized_keys

# サーバーからログアウト（自分の PC に戻る）
exit
```

#### 秘密鍵の内容を確認

**自分の PC のターミナルに戻っていることを確認してから実行:**

```bash
# 自分の PC で実行（サーバーではなく！）
cat ~/.ssh/uketori-deploy
```

`-----BEGIN OPENSSH PRIVATE KEY-----` から `-----END OPENSSH PRIVATE KEY-----` までの全文をコピー。

---

### 11-2. GitHub にシークレットを登録

1. GitHub のリポジトリページ → 「Settings」→「Secrets and variables」→「Actions」
2. 「New repository secret」で以下の2つを登録:

| Name | Value |
|------|-------|
| `LIGHTSAIL_HOST` | Lightsail の静的 IP アドレス |
| `LIGHTSAIL_SSH_KEY` | 上でコピーした秘密鍵の全文 |

---

### 11-3. デプロイ用ワークフローを作成

**自分の PC で**、以下のファイルを新規作成:

`.github/workflows/deploy.yml`

```yaml
name: Test & Deploy

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
        ports:
          - 5432:5432
    env:
      DATABASE_URL: postgres://postgres:password@localhost:5432/uketori_test
      RAILS_ENV: test
      JWT_SECRET: test-secret-key
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'
          bundler-cache: true
          working-directory: api
      - name: Setup database
        working-directory: api
        run: bin/rails db:create db:migrate
      - name: Run RSpec
        working-directory: api
        run: bundle exec rspec
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
          cache-dependency-path: web/package-lock.json
      - name: Build frontend
        working-directory: web
        run: npm ci && npm run build

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
```

コミットしてプッシュ:

```bash
cd /Users/e0195/重要/uketori
git add .github/workflows/deploy.yml
git commit -m "CI/CD: テスト→自動デプロイを追加"
git push
```

これ以降、`main` ブランチに `git push` すると:

1. テスト（RSpec + Next.js ビルド）が自動実行される
2. テストが通ったら SSH でサーバーに接続して自動デプロイされる
3. Vercel も自動でフロントエンドをデプロイする

> **GitHub Actions の実行状況:** GitHub リポジトリの「Actions」タブで確認できます。

---

## Step 12: 最終確認

すべての Step が完了したら、以下のチェックリストを**上から順番に**確認します。
1つでも失敗したら、該当 Step に戻って修正してください。

---

### 12-1. インフラ基本チェック

**SSH でサーバーに接続して確認:**

```bash
ssh uketori
```

| # | 確認内容 | コマンド | 期待される結果 |
|---|---------|---------|--------------|
| 1 | Docker コンテナが動いている | `docker compose -f docker-compose.production.yml ps` | STATUS が `Up` |
| 2 | Rails が応答する | `curl http://localhost:8080/up` | HTTP 200 の応答 |
| 3 | Nginx が動いている | `sudo systemctl status nginx` | `active (running)` |
| 4 | SSL 証明書が有効 | `sudo certbot certificates` | 有効期限が表示される |
| 5 | スワップが有効 | `free -h` | Swap の行が 0 でない |
| 6 | タイムゾーンが JST | `timedatectl` | `Asia/Tokyo` |
| 7 | ディスク容量に余裕がある | `df -h /` | 使用率が 80% 未満 |

---

### 12-2. 外部アクセスチェック

**自分の PC のブラウザで確認:**

| # | 確認内容 | URL | 期待される結果 |
|---|---------|-----|--------------|
| 1 | API が HTTPS で応答 | `https://api.invoiceflow.jp/up` | 応答あり＋鍵マーク表示 |
| 2 | フロントが表示される | `https://app.invoiceflow.jp` | ログイン画面が表示 |
| 3 | HTTP → HTTPS リダイレクト | `http://api.invoiceflow.jp/up` | 自動で HTTPS に転送される |

---

### 12-3. 認証・ユーザー管理チェック

| # | 確認内容 | 手順 |
|---|---------|------|
| 1 | ログインできる | シードで作成したアカウントでログイン |
| 2 | テナント情報を編集できる | 設定 → 自社情報で会社名等を入力して保存 |
| 3 | パスワードリセットメールが届く | ログアウト → 「パスワードを忘れた方」→ メールが届く |
| 4 | ユーザー招待メールが届く | 設定 → ユーザー管理 → 新しいユーザーを招待 |

---

### 12-4. 顧客管理チェック

| # | 確認内容 | 手順 |
|---|---------|------|
| 1 | 顧客を新規作成できる | 顧客一覧 → 新規作成 → 会社名等を入力して保存 |
| 2 | 顧客を編集できる | 顧客詳細 → 編集 → 変更して保存 |
| 3 | 顧客を削除できる | 顧客一覧 → 削除 |
| 4 | 適格請求書番号の検証ができる | 顧客編集で T+13桁の番号を入力して検証ボタン |

---

### 12-5. 帳票（見積・請求）チェック

| # | 確認内容 | 手順 |
|---|---------|------|
| 1 | 見積書を作成できる | 帳票 → 新規作成 → 明細行を追加して保存 |
| 2 | 金額が正しく計算される | 税率別集計（10%/8%/非課税）が正しいか確認 |
| 3 | PDF をダウンロードできる | 帳票詳細 → PDF ダウンロード |
| 4 | 見積書→請求書に変換できる | 帳票詳細 → 「請求書に変換」 |
| 5 | メールで帳票を送信できる | 帳票詳細 → 送信 → 実際にメールが届くか |

---

### 12-6. 入金回収チェック（★ MVP 核心機能）

| # | 確認内容 | 手順 |
|---|---------|------|
| 1 | 入金を手動で記録できる | 入金一覧 → 新規入金記録 → 請求書と紐付け |
| 2 | 銀行明細 CSV を取り込める | 入金管理 → 銀行明細取込 → CSV アップロード |
| 3 | AI 消込が動作する | 銀行明細取込後、AI マッチング結果が表示される |
| 4 | 回収ダッシュボードが表示される | 回収ダッシュボード → 売掛金年齢表・KPI が表示される |

> **AI 消込の確認には** Claude API キー（`ANTHROPIC_API_KEY`）が正しく設定されている必要があります。
> エラーが出る場合は `docker compose -f docker-compose.production.yml logs --tail 50` でログを確認してください。

---

### 12-7. 督促チェック（★ MVP 核心機能）

| # | 確認内容 | 手順 |
|---|---------|------|
| 1 | 督促ルールが設定できる | 設定 → 督促ルール → ルールを作成 |
| 2 | 督促メールが送信される | テスト用に支払期日が過ぎた請求書を作成 → 督促実行 |

---

### 12-8. データ移行チェック（★ MVP 核心機能）

| # | 確認内容 | 手順 |
|---|---------|------|
| 1 | データ移行ウィザードが開ける | メニュー → データ移行 |
| 2 | CSV/Excel をアップロードできる | テスト用の CSV ファイルでインポートを試す |
| 3 | AI マッピングが動作する | カラム自動認識結果が表示される |
| 4 | プレビュー後にインポートできる | プレビュー確認 → インポート実行 → データが登録される |

---

### 12-9. 定期ジョブチェック

**SSH でサーバーに接続して確認:**

```bash
ssh uketori
cd /home/ubuntu/uketori

# SolidQueue が動作しているか確認
docker compose -f docker-compose.production.yml exec -T api bin/rails runner \
  "puts 'SolidQueue ready jobs: ' + SolidQueue::ReadyExecution.count.to_s; puts 'SolidQueue recurring tasks: ' + SolidQueue::RecurringTask.count.to_s"
```

| 期待される結果 | 意味 |
|--------------|------|
| `SolidQueue recurring tasks: 6` 前後 | 定期ジョブが6つ登録されている（recurring.yml の設定数） |

> 定期ジョブが 0 件の場合、SolidQueue が正しく起動していません。
> `SOLID_QUEUE_IN_PUMA=true` が `.env.production` に設定されているか確認してください。

---

### 12-10. 監視チェック

| # | 確認内容 | 手順 |
|---|---------|------|
| 1 | Sentry にテストエラーが記録される | Rails コンソールで `Sentry.capture_message("Deploy test")` を実行 → Sentry ダッシュボードで確認 |
| 2 | BetterStack にモニターが表示される | BetterStack ダッシュボードでステータスが「Up」 |

**Sentry テストの実行方法:**

```bash
docker compose -f docker-compose.production.yml exec api bin/rails runner \
  "Sentry.capture_message('Deploy verification test')"
```

---

### 12-11. バックアップチェック

```bash
# 手動バックアップを実行してみる
bash /home/ubuntu/backup.sh

# バックアップファイルが作成されたか確認
ls -la /home/ubuntu/backups/
```

ファイル（例: `uketori_20260406_120000.sql.gz`）が作成されていれば OK です。

---

## トラブルシューティング

### よくあるエラーと対処法

| 症状 | 原因と対策 |
|------|-----------|
| API にアクセスすると 502 Bad Gateway | Docker コンテナが停止している → `docker compose -f docker-compose.production.yml up -d` |
| API にアクセスすると 502（コンテナは動いている） | Rails の起動に失敗 → `docker compose -f docker-compose.production.yml logs` でエラー確認 |
| ログイン後にエラー画面 | `CORS_ORIGINS` がフロントエンドの URL と一致しているか確認 |
| PDF がダウンロードできない | `R2_ENDPOINT` と `MINIO_EXTERNAL_URL` が正しいか確認 |
| メールが届かない | `RESEND_API_KEY` が正しいか、ドメイン認証が完了しているか確認 |
| 画像がアップロードできない | `R2_ACCESS_KEY_ID` と `R2_SECRET_ACCESS_KEY` を確認 |
| Internal Server Error | `docker compose ... logs` を確認。`SECRET_KEY_BASE` が設定されているか確認 |
| フロントから API にアクセスできない | Vercel の `NEXT_PUBLIC_API_URL` が API の URL と一致しているか確認 |
| SSL 証明書エラー | `sudo certbot renew` を実行。DNS レコードが正しいか確認 |
| Docker ビルドが遅い/失敗する | `docker system prune` でキャッシュを削除。ディスク容量を確認: `df -h` |

---

## 便利なコマンド集

サーバーでよく使うコマンドをまとめました。

### サーバー接続

```bash
# サーバーに SSH 接続
ssh uketori
```

### Docker 関連

```bash
# コンテナの状態確認
docker compose -f docker-compose.production.yml ps

# ログをリアルタイムで表示（Ctrl+C で終了）
docker compose -f docker-compose.production.yml logs -f

# ログの最新50行を表示
docker compose -f docker-compose.production.yml logs --tail 50

# コンテナを再起動
docker compose -f docker-compose.production.yml restart

# コンテナを停止
docker compose -f docker-compose.production.yml down

# コンテナを起動
docker compose -f docker-compose.production.yml up -d

# Rails コンソール（デバッグ用）
docker compose -f docker-compose.production.yml exec api bin/rails console

# DB マイグレーション
docker compose -f docker-compose.production.yml exec -T api bin/rails db:migrate
```

### Nginx 関連

```bash
# 設定テスト
sudo nginx -t

# 再読み込み（設定変更後）
sudo systemctl reload nginx

# エラーログ確認
sudo tail -50 /var/log/nginx/error.log

# アクセスログ確認
sudo tail -50 /var/log/nginx/access.log
```

### SSL 証明書

```bash
# 証明書の有効期限確認
sudo certbot certificates

# 証明書の手動更新
sudo certbot renew
```

### サーバーの状態確認

```bash
# メモリ使用量
free -h

# ディスク使用量
df -h

# CPU / メモリ（リアルタイム、q で終了）
top
```

### 手動デプロイ

```bash
cd /home/ubuntu/uketori
bash deploy.sh
```

---

## 設定した環境変数の全一覧（最終確認用）

### Lightsail サーバー (.env.production)

| 変数名 | 値の例 | どの Step で設定したか |
|--------|--------|---------------------|
| `SECRET_KEY_BASE` | （rails secret で生成） | Step 5-7 |
| `DATABASE_URL` | `postgres://...@ep-xxx.neon.tech/...?sslmode=require` | Step 5-7 (Step 3 で取得) |
| `JWT_SECRET` | （openssl rand -hex 64 で生成） | Step 5-7 |
| `JWT_EXPIRATION` | `900` | Step 5-7 |
| `JWT_REFRESH_EXPIRATION` | `604800` | Step 5-7 |
| `ANTHROPIC_API_KEY` | `sk-ant-...` | Step 5-7 |
| `R2_ENDPOINT` | `https://xxx.r2.cloudflarestorage.com` | Step 5-7 (Step 4 で取得) |
| `R2_ACCESS_KEY_ID` | （R2 で取得した値） | Step 5-7 (Step 4 で取得) |
| `R2_SECRET_ACCESS_KEY` | （R2 で取得した値） | Step 5-7 (Step 4 で取得) |
| `R2_BUCKET` | `uketori-production` | Step 5-7 |
| `MINIO_EXTERNAL_URL` | （`R2_ENDPOINT` と同じ値） | Step 5-7 |
| `CORS_ORIGINS` | `https://app.invoiceflow.jp` | Step 7-8 |
| `FRONTEND_URL` | `https://app.invoiceflow.jp` | Step 7-8 |
| `APP_HOST` | `app.invoiceflow.jp` | Step 7-8 |
| `MAILER_FROM` | `noreply@invoiceflow.jp` | Step 7-8 |
| `RESEND_API_KEY` | `re_...` | Step 8-4 |
| `NTA_APP_ID` | （国税庁APIで取得） | Step 5-7 |
| `SENTRY_DSN` | `https://...@sentry.io/...` | Step 9-3 |
| `RAILS_LOG_LEVEL` | `info` | Step 5-7 |

### Vercel (Next.js)

| 変数名 | 値の例 | どの Step で設定したか |
|--------|--------|---------------------|
| `NEXT_PUBLIC_API_URL` | `https://api.invoiceflow.jp` | Step 6-3, Step 7-8 |

---

## 未実装の機能（今は対応不要）

以下は MVP デプロイには不要です。ユーザーが増えてから対応します。

| 機能 | 時期 | 備考 |
|------|------|------|
| Stripe 課金 | Phase 3 | 当面は free プランで運用 |
| 2段階認証 | Phase 3 | |
| 会計ソフト連携 CSV | Phase 2 | |
| 定期請求・一括請求 | Phase 2 | |
| AI 売上予測 / OCR | Phase 3 | |
| 負荷テスト | リリース前 | |

---

## 法務（有料プラン提供前に必要）

- [ ] **利用規約**
- [ ] **プライバシーポリシー**
- [ ] **特定商取引法に基づく表記**

---

## スケールアップ手順書

ユーザーが増えてきたら、以下の段階に沿ってインフラを拡張します。
**「いつ」「何を見て」「何をするか」** を具体的に記載しています。

### スケールアップ全体像

```
Phase 1: 学習・開発         Lightsail Nano  ($5)   ¥750/月
    ↓ 有料ユーザー獲得
Phase 2: 本番運用開始        Lightsail Micro ($7)   ¥1,050/月
    ↓ 50ユーザー超 or レスポンス低下
Phase 3: 成長期             Lightsail Small ($12)  ¥1,800/月
    ↓ 200ユーザー超 or DB容量逼迫
Phase 4: 拡大期             Lightsail Medium ($24) + Neon Pro ($19)  ¥6,500/月
    ↓ 500ユーザー超 or 可用性要件
Phase 5: 本格スケール       EC2 + RDS + ALB        ¥20,000〜/月
    ↓ 1,000ユーザー超
Phase 6: フルスケール       ECS + Aurora + ElastiCache  ¥50,000〜/月
```

---

### スケールアップのタイミング判断方法

**「いつスケールアップすべきか」を判断するために、以下のコマンドを定期的に実行してください。**

```bash
ssh uketori
```

#### メモリ使用量の確認

```bash
free -h
```

```
              total        used        free      shared  buff/cache   available
Mem:          976Mi       750Mi        50Mi       10Mi       176Mi       100Mi  ← available が 100MB 以下なら要注意
Swap:         2.0Gi       500Mi       1.5Gi                              ← Swap が 500MB 以上使われていたら要注意
```

| 状態 | 判断 |
|------|------|
| available が RAM の 20% 以上 | 正常。スケールアップ不要 |
| available が RAM の 10〜20% | 注意。1ヶ月以内にスケールアップを検討 |
| available が RAM の 10% 未満 | 危険。すぐにスケールアップ |
| Swap が 500MB 以上使用中 | プラン不足。スケールアップ推奨 |

#### CPU 使用率の確認

```bash
# 5秒間の平均 CPU 使用率を表示
top -bn1 | head -5
```

`%Cpu(s):` の行を確認。`us`（ユーザー使用率）+ `sy`（システム使用率）の合計が：

| 状態 | 判断 |
|------|------|
| 50% 未満 | 正常 |
| 50〜80% | 注意。ピーク時間帯に継続的なら検討 |
| 80% 以上 | 危険。すぐにスケールアップ |

#### API レスポンス時間の確認

```bash
# API のレスポンス時間を測定（ミリ秒で表示）
curl -o /dev/null -s -w "レスポンス時間: %{time_total}秒\n" http://localhost:8080/up
```

| 状態 | 判断 |
|------|------|
| 0.5秒未満 | 正常 |
| 0.5〜1.0秒 | 注意 |
| 1.0秒以上 | スケールアップ推奨 |

#### ディスク使用量の確認

```bash
df -h /
```

| 状態 | 判断 |
|------|------|
| 使用率 60% 未満 | 正常 |
| 60〜80% | Docker の古いイメージを削除: `docker system prune -f` |
| 80% 以上 | スケールアップ推奨 |

---

### Phase 1→2: Nano ($5) → Micro ($7)

**タイミング:** 最初の有料ユーザーを迎える時、または Swap 使用量が常時 500MB を超える時

**所要時間:** 約30分
**ダウンタイム:** 約5〜10分

#### 手順

**1. 現在のサーバーのスナップショットを作成**

「スナップショット」とは、サーバーの中身をそのまま写真のように保存する機能です。万が一失敗しても、この時点の状態に戻れます。

1. https://lightsail.aws.amazon.com にアクセス
2. `uketori-api` をクリック
3. 「スナップショット」タブをクリック
4. 「手動スナップショットの作成」をクリック
5. 名前: `uketori-api-before-upgrade-YYYYMMDD`（日付を入れる）
6. 「作成」をクリック
7. ステータスが **「使用可能」** になるまで待つ（5〜10分）

**2. スナップショットから新しいインスタンスを作成**

1. 作成したスナップショットの右の「⋮」メニュー →「新しいインスタンスの作成」
2. 以下を設定:

| 設定項目 | 値 |
|---------|-----|
| リージョン | 東京（元と同じ） |
| インスタンスプラン | **Micro-1GB ($7)** ← ここで上位プランを選ぶ |
| インスタンス名 | `uketori-api-new` |

3. 「インスタンスの作成」をクリック
4. 状態が **「実行中」** になるまで待つ

**3. 新しいインスタンスの動作確認**

新しいインスタンスの **パブリック IP** を確認し（Lightsail ダッシュボードに表示される）、SSH で接続:

```bash
# 新しいインスタンスに一時的に接続（IPは新しいもの）
ssh -i ~/Downloads/LightsailDefaultKey-ap-northeast-1.pem ubuntu@新しいIPアドレス
```

```bash
# Docker が動いているか確認
docker compose -f /home/ubuntu/uketori/docker-compose.production.yml ps

# API が応答するか確認
curl http://localhost:8080/up
```

応答があれば OK です。`exit` でログアウト。

**4. 静的 IP を付け替える（ここでダウンタイムが発生します）**

1. Lightsail ダッシュボード → 左メニュー「ネットワーキング」
2. `uketori-api-ip`（静的 IP）をクリック
3. 「デタッチ」をクリック（**旧インスタンスから外す**）
4. 「アタッチ先」で **`uketori-api-new`** を選択
5. 「アタッチ」をクリック

> この「デタッチ→アタッチ」の間（約1〜2分）だけダウンタイムが発生します。

**5. 動作確認**

```bash
# 元の SSH 設定で接続できるか確認（静的IPは同じなので接続先は変わらない）
ssh uketori

# メモリが増えているか確認
free -h

# API が動いているか確認
curl http://localhost:8080/up
```

`Mem: total` の値が新しいプランの RAM（1GB なら `976Mi` 程度）になっていれば成功です。

**6. 旧インスタンスを削除**

動作確認が完了し、1日程度問題なく動いたら:

1. Lightsail ダッシュボード → `uketori-api`（旧インスタンス）をクリック
2. 「削除」タブ → 「インスタンスの削除」
3. 確認画面で「はい、削除します」

> **注意:** スナップショットは残しておいてください。万が一問題が出た場合に戻れます。
> 不要になったスナップショットは 1 週間後に削除しても OK です（スナップショットにも若干の料金がかかります）。

---

### Phase 2→3: Micro ($7) → Small ($12)

**タイミング:** 50ユーザー超、または API レスポンスが常時 0.5秒以上

**手順は Phase 1→2 と全く同じです。** 唯一の違いは:

| 手順 | 変更点 |
|------|--------|
| 手順2 のインスタンスプラン | **Small-2GB ($12)** を選ぶ |

---

### Phase 3→4: Small ($12) → Medium ($24) + Neon Pro

**タイミング:** 200ユーザー超、または以下のいずれかに該当:
- Neon Free の 0.5GB ストレージ上限に近づいている
- Neon のコンピュート時間（191時間/月）を超過しそう
- SolidQueue のジョブが遅延している

**所要時間:** 約1時間
**ダウンタイム:** 約5〜10分（Lightsail の切り替え時のみ）

#### 手順 A: Lightsail のプランアップ

Phase 1→2 と同じ手順で、**Medium-4GB ($24)** にアップグレードしてください。

#### 手順 B: Neon を Pro プランにアップグレード

1. https://console.neon.tech にログイン
2. プロジェクト `uketori` を選択
3. 左メニュー「Settings」→「Billing」
4. 「Upgrade to Pro」をクリック
5. 支払い情報を入力（まだの場合）
6. 「Upgrade」をクリック

**Pro プランで変わること:**

| 項目 | Free | Pro ($19/月) |
|------|------|-------------|
| ストレージ | 0.5GB | 10GB（超過分は $0.15/GB） |
| コンピュート時間 | 191時間/月 | 300時間/月（超過分は従量課金） |
| 自動スリープ | 5分で停止 | 5分で停止（設定変更可能） |
| ブランチ数 | 10 | 無制限 |

> **Neon Pro で「自動スリープまでの時間」を延長する（推奨）:**
>
> 1. Neon ダッシュボード → プロジェクト → 「Settings」→「Compute」
> 2. 「Auto-suspend delay」を `5 minutes` → `30 minutes` に変更
>
> これでコールドスタート（スリープ復帰に 1〜2秒かかる現象）の頻度が大幅に減ります。

#### 手順 C: SolidQueue を別プロセスに分離（推奨）

ユーザーが増えると、Puma（Web リクエスト処理）と SolidQueue（バックグラウンドジョブ）が同じプロセスでメモリを取り合います。分離すると安定性が向上します。

**1. サーバーに SSH 接続:**

```bash
ssh uketori
cd /home/ubuntu/uketori
```

**2. `.env.production` を編集:**

```bash
nano .env.production
```

以下の行を変更:

```bash
# 変更前
SOLID_QUEUE_IN_PUMA=true

# 変更後
SOLID_QUEUE_IN_PUMA=false
```

**3. `docker-compose.production.yml` を編集:**

```bash
nano docker-compose.production.yml
```

`api` サービスの下に `worker` サービスを追加:

```yaml
services:
  api:
    build:
      context: ./api
    ports:
      - "127.0.0.1:8080:8080"
    env_file:
      - .env.production
    environment:
      - RAILS_ENV=production
      - PORT=8080
      - SOLID_QUEUE_IN_PUMA=false
    restart: always
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  worker:
    build:
      context: ./api
    env_file:
      - .env.production
    environment:
      - RAILS_ENV=production
    command: ["bundle", "exec", "rake", "solid_queue:start"]
    restart: always
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

**4. 再起動:**

```bash
docker compose -f docker-compose.production.yml build
docker compose -f docker-compose.production.yml up -d
```

**5. 確認:**

```bash
docker compose -f docker-compose.production.yml ps
```

`api` と `worker` の2つのコンテナが `Up` になっていれば成功です。

```bash
# worker のログを確認（SolidQueue が動いているか）
docker compose -f docker-compose.production.yml logs worker --tail 20
```

`SolidQueue-0.x.x started` のようなログが出ていれば OK です。

---

### Phase 4→5: Lightsail → EC2 + RDS + ALB

**タイミング:** 500ユーザー超、または以下のいずれかに該当:
- 高可用性（ダウンタイム最小化）が必要
- オートスケーリングが必要
- Neon のレイテンシ（シンガポールリージョン）が問題になっている

**所要時間:** 4〜8時間（初めての場合）
**ダウンタイム:** DNS 切り替え時の数分のみ（事前準備をすれば）

> **注意:** この Phase からは AWS の中級スキルが必要です。
> 不安な場合は、AWS のソリューションアーキテクトに相談（無料枠あり）するか、
> 経験のあるインフラエンジニアに依頼することを推奨します。

#### 構成の変更点

```
【Phase 4 まで】
ユーザー → Cloudflare → Lightsail (Nginx + Docker + Rails)
                                  ↓
                              Neon (DB)

【Phase 5】
ユーザー → Cloudflare → ALB (ロードバランサー)
                          ↓
                    EC2 × 2台 (Docker + Rails)
                          ↓
                    RDS PostgreSQL (東京リージョン)
```

#### 手順概要

**1. RDS PostgreSQL を作成**

1. AWS コンソール → RDS → 「データベースの作成」
2. 設定:

| 設定項目 | 値 |
|---------|-----|
| エンジン | PostgreSQL 16 |
| テンプレート | 開発/テスト（本番用は「本番稼働用」） |
| インスタンスクラス | `db.t3.micro`（最小。約 $15/月） |
| ストレージ | 汎用 SSD (gp3)、20GB |
| マルチ AZ | いいえ（コスト節約。500ユーザーなら不要） |
| VPC | デフォルト VPC |
| パブリックアクセス | いいえ |
| DB名 | `uketori_production` |

3. 作成完了後、エンドポイント（`xxx.xxx.ap-northeast-1.rds.amazonaws.com`）をメモ

**2. Neon → RDS にデータを移行**

```bash
# Lightsail サーバーで実行

# 1. Neon からデータをダンプ
docker compose -f docker-compose.production.yml exec -T api \
  bash -c "pg_dump \$(bin/rails runner \"puts ENV['DATABASE_URL']\" | tail -1) --no-owner --no-privileges" \
  > /home/ubuntu/neon_dump.sql

# 2. RDS にデータをリストア（RDSのエンドポイント・パスワードに置き換え）
sudo apt install -y postgresql-client
psql "postgres://postgres:パスワード@RDSエンドポイント:5432/uketori_production" < /home/ubuntu/neon_dump.sql
```

**3. EC2 インスタンスを作成**

1. AWS コンソール → EC2 → 「インスタンスの起動」
2. 設定:

| 設定項目 | 値 |
|---------|-----|
| AMI | Ubuntu 22.04 LTS |
| インスタンスタイプ | `t3.small`（2GB RAM。約 $15/月） |
| キーペア | Lightsail で使っていたものを再利用 or 新規作成 |
| VPC / サブネット | RDS と同じ VPC |
| セキュリティグループ | SSH(22) + HTTP(8080) を許可 |

3. EC2 に Docker をインストール → Lightsail と同じ手順
4. コードを clone → `.env.production` の `DATABASE_URL` を RDS のものに変更
5. Docker Compose で起動

**4. ALB（ロードバランサー）を作成**

1. AWS コンソール → EC2 → ロードバランサー → 「作成」
2. タイプ: **Application Load Balancer**
3. リスナー: HTTPS (443)
4. ターゲットグループ: EC2 インスタンスのポート 8080
5. SSL 証明書: AWS Certificate Manager (ACM) で無料取得

**5. DNS を切り替え**

Cloudflare の DNS レコードを変更:

| Type | Name | Content | 変更点 |
|------|------|---------|--------|
| A → CNAME | `api` | ALB の DNS 名 | Lightsail IP → ALB に変更 |

**6. 動作確認後、Lightsail インスタンスを停止・削除**

> **この Phase の詳細な手順** は、実施するタイミングで AWS の最新ドキュメントを参照してください。
> AWS は頻繁に画面や手順が更新されるため、古い手順のまま実施するとエラーになることがあります。
>
> 参考: https://docs.aws.amazon.com/ja_jp/elasticloadbalancing/latest/application/

---

### Phase 5→6: EC2 → ECS (Fargate) + Aurora

**タイミング:** 1,000ユーザー超、または以下のいずれか:
- EC2 の手動管理が運用負荷になっている
- オートスケーリング（負荷に応じた自動台数調整）が必要
- DB の読み込み負荷が高い（リードレプリカが必要）

> **この Phase は高度なインフラスキルが必要です。**
> この段階に達する頃には、売上も相応にあるはずなので、
> インフラエンジニアの採用またはAWSパートナー企業への委託を強く推奨します。

#### 構成

```
ユーザー → CloudFront (CDN) → ALB
                                ↓
                          ECS Fargate (自動スケール)
                            ├─ api-service × N台
                            └─ worker-service × N台
                                ↓
                          Aurora PostgreSQL (自動スケール)
                            ├─ Writer (書き込み)
                            └─ Reader × N台 (読み込み)
                                ↓
                          ElastiCache Redis (セッション/キャッシュ)
```

#### 主要な変更点

| 項目 | Phase 5 | Phase 6 |
|------|---------|---------|
| コンピュート | EC2（手動管理） | ECS Fargate（サーバーレス） |
| DB | RDS PostgreSQL | Aurora PostgreSQL（自動スケール） |
| キャッシュ | SolidCache（DB内） | ElastiCache Redis |
| スケーリング | 手動 | オートスケーリング |
| デプロイ | SSH + Docker Compose | ECR + ECS ローリングデプロイ |

#### 概算コスト

| サービス | 月額目安 |
|---------|---------|
| ECS Fargate (API × 2) | ¥8,000〜15,000 |
| ECS Fargate (Worker × 1) | ¥4,000〜8,000 |
| Aurora PostgreSQL | ¥15,000〜30,000 |
| ElastiCache Redis | ¥5,000〜10,000 |
| ALB | ¥3,000〜5,000 |
| CloudFront | ¥1,000〜3,000 |
| その他（ECR, CloudWatch等） | ¥2,000〜5,000 |
| **合計** | **¥38,000〜76,000** |

---

### スケールアップ時の共通チェックリスト

どの Phase のスケールアップでも、完了後に以下を必ず確認してください:

| # | 確認内容 | コマンド / 方法 |
|---|---------|---------------|
| 1 | API が応答する | `curl https://api.ドメイン/up` |
| 2 | ログインできる | ブラウザでログイン |
| 3 | PDF が生成できる | 帳票を作成して PDF ダウンロード |
| 4 | メールが送信できる | パスワードリセットを試す |
| 5 | AI 機能が動く | AI 消込を試す |
| 6 | 定期ジョブが動いている | SolidQueue の RecurringTask 数を確認 |
| 7 | BetterStack が「Up」 | BetterStack ダッシュボードを確認 |
| 8 | バックアップが動く | `bash /home/ubuntu/backup.sh` を手動実行 |
| 9 | Sentry にエラーがない | Sentry ダッシュボードを確認 |
