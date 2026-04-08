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