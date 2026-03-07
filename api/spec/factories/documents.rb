# frozen_string_literal: true

FactoryBot.define do
  factory :document do
    tenant
    customer
    association :created_by_user, factory: :user
    sequence(:document_number) { |n| "DOC-#{n.to_s.rjust(4, '0')}" }
    document_type { "estimate" }
    status { "draft" }
    issue_date { Date.current }

    trait :estimate do
      document_type { "estimate" }
      sequence(:document_number) { |n| "EST-#{n.to_s.rjust(4, '0')}" }
    end

    trait :invoice do
      document_type { "invoice" }
      sequence(:document_number) { |n| "INV-#{n.to_s.rjust(4, '0')}" }
      payment_status { "unpaid" }
      due_date { 30.days.from_now.to_date }
    end

    trait :purchase_order do
      document_type { "purchase_order" }
      sequence(:document_number) { |n| "PO-#{n.to_s.rjust(4, '0')}" }
    end

    trait :approved do
      status { "approved" }
    end

    trait :sent do
      status { "sent" }
      sent_at { Time.current }
    end

    trait :locked do
      status { "locked" }
      locked_at { Time.current }
    end

    trait :with_items do
      after(:create) do |doc|
        create_list(:document_item, 2, document: doc)
        doc.recalculate_amounts!
      end
    end
  end
end
