# frozen_string_literal: true

FactoryBot.define do
  factory :payment_record do
    tenant
    association :document, factory: %i[document invoice]
    association :recorded_by_user, factory: :user
    uuid { SecureRandom.uuid }
    amount { 10_000 }
    payment_date { Date.current }
    payment_method { "bank_transfer" }
    matched_by { "manual" }

    trait :ai_auto do
      matched_by { "ai_auto" }
      match_confidence { 0.95 }
    end

    trait :ai_suggested do
      matched_by { "ai_suggested" }
      match_confidence { 0.80 }
    end

    trait :with_bank_statement do
      association :bank_statement
    end
  end
end
