# frozen_string_literal: true

FactoryBot.define do
  factory :dunning_rule do
    tenant
    sequence(:name) { |n| "督促ルール#{n}" }
    trigger_days_after_due { 7 }
    action_type { "email" }
    email_template_subject { "【{{company_name}}】お支払いのお願い（{{document_number}}）" }
    email_template_body { "{{customer_name}} 様\n\n{{document_number}} の支払期限（{{due_date}}）を{{overdue_days}}日超過しております。\n未払い残高: ¥{{remaining_amount}}" }
    send_to { "billing_contact" }
    is_active { true }
    sort_order { 0 }
    max_dunning_count { 3 }
    interval_days { 7 }

    trait :inactive do
      is_active { false }
    end

    trait :gentle do
      name { "やんわり催促" }
      trigger_days_after_due { 1 }
    end

    trait :strong do
      name { "強い催促" }
      trigger_days_after_due { 21 }
    end

    trait :final do
      name { "最終通告" }
      trigger_days_after_due { 45 }
    end
  end
end
