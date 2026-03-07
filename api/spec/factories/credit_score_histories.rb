# frozen_string_literal: true

FactoryBot.define do
  factory :credit_score_history do
    tenant
    customer
    score { 50 }
    factors { { late_count: 0, early_count: 3, avg_days: 15 } }
    calculated_at { Time.current }
  end
end
