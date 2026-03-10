require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

module Api
  class Application < Rails::Application
    config.load_defaults 8.0

    config.autoload_lib(ignore: %w[assets tasks])

    # app/errors をautoloadパスに追加
    config.autoload_paths << Rails.root.join("app/errors")

    # API only
    config.api_only = true


    # タイムゾーン
    config.time_zone = "Asia/Tokyo"
    config.active_record.default_timezone = :utc

    # ロケール
    config.i18n.default_locale = :ja
    config.i18n.available_locales = %i[ja en]

    # ActiveJob
    config.active_job.queue_adapter = :solid_queue

    # Generator設定
    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot, dir: "spec/factories"
      g.skip_routes true
      g.helper false
      g.assets false
    end
  end
end
