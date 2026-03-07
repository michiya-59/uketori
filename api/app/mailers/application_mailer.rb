# frozen_string_literal: true

# 全メーラーの基底クラス
class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAILER_FROM", "noreply@uketori.app") }
  layout "mailer"
end
