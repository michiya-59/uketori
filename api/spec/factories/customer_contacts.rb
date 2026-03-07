# frozen_string_literal: true

FactoryBot.define do
  factory :customer_contact do
    customer
    sequence(:name) { |n| "担当者#{n}" }
    sequence(:email) { |n| "contact#{n}@example.com" }
    phone { "03-1234-5678" }
    department { "営業部" }
    title { "主任" }
    is_primary { false }
    is_billing_contact { false }

    trait :primary do
      is_primary { true }
    end

    trait :billing do
      is_billing_contact { true }
    end
  end
end
