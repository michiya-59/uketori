# frozen_string_literal: true

FactoryBot.define do
  factory :project do
    tenant
    customer
    sequence(:project_number) { |n| "PRJ-#{n.to_s.rjust(4, '0')}" }
    sequence(:name) { |n| "テスト案件#{n}" }
    status { "negotiation" }
    probability { 50 }

    trait :won do
      status { "won" }
    end

    trait :in_progress do
      status { "in_progress" }
    end
  end
end
