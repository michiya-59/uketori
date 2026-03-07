# frozen_string_literal: true

FactoryBot.define do
  factory :customer do
    tenant
    company_name { "株式会社テスト取引先" }
    customer_type { "client" }

    trait :vendor do
      customer_type { "vendor" }
    end

    trait :with_invoice_number do
      invoice_registration_number { "T9876543210123" }
    end

    trait :with_contact do
      contact_name { "テスト 太郎" }
      email { "test@example.com" }
      phone { "03-9999-8888" }
    end

    trait :with_address do
      postal_code { "150-0001" }
      prefecture { "東京都" }
      city { "渋谷区" }
      address_line1 { "神宮前1-1-1" }
    end

    trait :high_risk do
      credit_score { 20 }
    end
  end
end
