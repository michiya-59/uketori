# frozen_string_literal: true

FactoryBot.define do
  factory :document_version do
    document
    association :changed_by_user, factory: :user
    version { 1 }
    snapshot { { document_type: "estimate", status: "draft" } }
    change_reason { "初回作成" }
  end
end
