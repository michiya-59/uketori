# frozen_string_literal: true

FactoryBot.define do
  factory :dunning_log do
    tenant
    association :document, factory: %i[document invoice]
    dunning_rule
    customer
    action_type { "email" }
    sent_to_email { "billing@example.com" }
    email_subject { "お支払いのお願い" }
    email_body { "テスト本文" }
    status { "sent" }
    overdue_days { 7 }
    remaining_amount { 100_000 }

    trait :failed do
      status { "failed" }
    end
  end
end
