# frozen_string_literal: true

FactoryBot.define do
  factory :document_item do
    document
    sequence(:name) { |n| "明細行#{n}" }
    item_type { "normal" }
    quantity { 1 }
    unit { "個" }
    unit_price { 10_000 }
    tax_rate { 10.0 }
    tax_rate_type { "standard" }
    sort_order { 0 }

    trait :discount do
      item_type { "discount" }
      name { "値引き" }
      unit_price { -1000 }
    end

    trait :reduced_tax do
      tax_rate { 8.0 }
      tax_rate_type { "reduced" }
    end
  end
end
