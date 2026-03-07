# frozen_string_literal: true

FactoryBot.define do
  factory :tenant do
    name { "テスト株式会社" }
    plan { "free" }
    industry_type { "general" }
    default_tax_rate { 10.0 }
    fiscal_year_start_month { 4 }
    default_payment_terms_days { 30 }

    trait :with_full_info do
      name_kana { "テストカブシキガイシャ" }
      postal_code { "100-0001" }
      prefecture { "東京都" }
      city { "千代田区" }
      address_line1 { "丸の内1-1-1" }
      address_line2 { "サンプルビル3F" }
      phone { "03-1234-5678" }
      fax { "03-1234-5679" }
      email { "info@test.co.jp" }
      website { "https://test.co.jp" }
      invoice_registration_number { "T1234567890123" }
      bank_name { "三菱UFJ銀行" }
      bank_branch_name { "丸の内支店" }
      bank_account_type { "ordinary" }
      bank_account_number { "1234567" }
      bank_account_holder { "テスト（カ" }
    end
  end
end
