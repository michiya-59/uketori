# frozen_string_literal: true

FactoryBot.define do
  factory :industry_template do
    sequence(:code) { |n| "industry_#{n}" }
    name { "テスト業種" }
    labels { { "customer" => "顧客", "product" => "品目" } }
    default_products { [{ "name" => "コンサルティング", "unit" => "時間" }] }
    default_statuses { [{ "key" => "draft", "label" => "下書き" }] }
    tax_settings { { "default_rate" => 10.0 } }
    sort_order { 0 }
    is_active { true }

    trait :inactive do
      is_active { false }
    end

    trait :construction do
      code { "construction" }
      name { "建設業" }
      sort_order { 1 }
    end

    trait :it do
      code { "it" }
      name { "IT・通信業" }
      sort_order { 2 }
    end
  end
end
