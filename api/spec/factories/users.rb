# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    tenant
    sequence(:name) { |n| "テストユーザー#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "Password123!" }
    password_confirmation { "Password123!" }
    role { "member" }

    trait :owner do
      role { "owner" }
    end

    trait :admin do
      role { "admin" }
    end

    trait :accountant do
      role { "accountant" }
    end

    trait :sales do
      role { "sales" }
    end

    trait :member do
      role { "member" }
    end

    trait :system_admin do
      system_admin { true }
    end
  end
end
