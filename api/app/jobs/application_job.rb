# frozen_string_literal: true

# アプリケーション共通のジョブ基底クラス
class ApplicationJob < ActiveJob::Base
  # リトライ設定
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
end
