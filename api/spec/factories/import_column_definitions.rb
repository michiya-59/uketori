# frozen_string_literal: true

FactoryBot.define do
  factory :import_column_definition do
    source_type { "board" }
    source_column_name { "会社名" }
    target_table { "customers" }
    target_column { "company_name" }
    is_required { true }

    trait :optional do
      is_required { false }
    end
  end
end
