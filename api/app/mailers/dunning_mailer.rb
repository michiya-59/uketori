# frozen_string_literal: true

# 督促メール送信用メーラー
#
# DunningExecutorから呼び出され、督促メールを送信する。
#
# @example
#   DunningMailer.send_dunning(dunning_log).deliver_later
class DunningMailer < ApplicationMailer
  # 督促メールを送信する
  #
  # @param dunning_log [DunningLog] 督促ログ
  # @return [Mail::Message]
  def send_dunning(dunning_log)
    @dunning_log = dunning_log
    @document = dunning_log.document
    @customer = dunning_log.customer
    @tenant = dunning_log.tenant

    mail(
      to: dunning_log.sent_to_email,
      subject: dunning_log.email_subject
    )
  end
end
