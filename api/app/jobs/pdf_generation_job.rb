# frozen_string_literal: true

# 帳票PDFを非同期で生成するジョブ
#
# SolidQueueにキューイングされ、バックグラウンドで
# PdfGeneratorサービスを呼び出してPDFを生成する。
#
# @example
#   PdfGenerationJob.perform_later(document.id)
class PdfGenerationJob < ApplicationJob
  queue_as :default

  # PDFを生成する
  #
  # @param document_id [Integer] 帳票ID
  # @return [void]
  def perform(document_id)
    document = Document.find(document_id)
    PdfGenerator.call(document)
  end
end
