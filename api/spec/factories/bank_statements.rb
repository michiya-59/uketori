# frozen_string_literal: true

FactoryBot.define do
  factory :bank_statement do
    tenant
    transaction_date { Date.current }
    description { "振込 カ）テストトリヒキサキ" }
    payer_name { "カ）テストトリヒキサキ" }
    amount { 100_000 }
    bank_name { "三菱UFJ銀行" }
    account_number { "1234567" }
    import_batch_id { SecureRandom.uuid }

    trait :matched do
      is_matched { true }
      association :matched_document, factory: %i[document invoice]
    end

    trait :unmatched do
      is_matched { false }
    end

    trait :with_ai_suggestion do
      is_matched { false }
      association :ai_suggested_document, factory: %i[document invoice]
      ai_match_confidence { 0.85 }
      ai_match_reason { "金額一致・振込名類似" }
    end
  end
end
