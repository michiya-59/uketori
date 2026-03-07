require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true

  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.public_file_server.headers = { "cache-control" => "public, max-age=#{2.days.to_i}" }
  else
    config.action_controller.perform_caching = false
  end

  config.cache_store = :memory_store

  # ActiveStorage: S3互換 (MinIO)
  config.active_storage.service = :amazon

  # ActionMailer: letter_opener相当（ログ出力）
  config.action_mailer.delivery_method = :log
  config.action_mailer.default_url_options = { host: "localhost", port: 4101 }

  config.active_support.deprecation = :log
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true
  config.active_record.query_log_tags_enabled = true
  config.action_controller.raise_on_missing_callback_actions = true
end
