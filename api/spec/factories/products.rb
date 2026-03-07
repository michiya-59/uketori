# frozen_string_literal: true

FactoryBot.define do
  factory :product do
    tenant
    sequence(:name) { |n| "テスト品目#{n}" }
    tax_rate_type { "standard" }
    tax_rate { 10.0 }
    unit { "個" }
    unit_price { 1000 }
    is_active { true }
    sort_order { 0 }

    trait :reduced_tax do
      tax_rate_type { "reduced" }
      tax_rate { 8.0 }
    end

    trait :exempt do
      tax_rate_type { "exempt" }
      tax_rate { 0.0 }
    end

    trait :inactive do
      is_active { false }
    end
  end
end
