# frozen_string_literal: true

FactoryBot.define do
  factory :import_job do
    tenant
    user
    source_type { "csv_generic" }
    status { "pending" }
    file_url { "https://storage.example.com/imports/#{SecureRandom.hex(8)}.csv" }
    file_name { "customers.csv" }
    file_size { 2048 }

    trait :board do
      source_type { "board" }
      file_name { "board_export.csv" }
    end

    trait :excel do
      source_type { "excel" }
      file_name { "data.xlsx" }
    end

    trait :parsing do
      status { "parsing" }
    end

    trait :mapping do
      status { "mapping" }
      parsed_data do
        {
          headers: %w[会社名 担当者 メールアドレス 電話番号],
          rows: [
            %w[テスト株式会社 山田太郎 yamada@example.com 03-1234-5678],
            %w[サンプル有限会社 佐藤花子 sato@example.com 06-9876-5432]
          ]
        }
      end
      ai_mapping_confidence { 0.85 }
    end

    trait :previewing do
      status { "previewing" }
      parsed_data do
        {
          headers: %w[会社名 担当者 メールアドレス 電話番号],
          rows: [
            %w[テスト株式会社 山田太郎 yamada@example.com 03-1234-5678]
          ]
        }
      end
      column_mapping do
        [
          { source: "会社名", target_table: "customers", target_column: "company_name", confidence: 0.95 },
          { source: "担当者", target_table: "customer_contacts", target_column: "name", confidence: 0.80 },
          { source: "メールアドレス", target_table: "customer_contacts", target_column: "email", confidence: 0.90 },
          { source: "電話番号", target_table: "customers", target_column: "phone", confidence: 0.85 }
        ]
      end
      preview_data do
        [
          { company_name: "テスト株式会社", contact_name: "山田太郎", email: "yamada@example.com", phone: "03-1234-5678" }
        ]
      end
    end

    trait :completed do
      status { "completed" }
      started_at { 5.minutes.ago }
      completed_at { Time.current }
      import_stats do
        { total_rows: 10, success_count: 8, error_count: 1, skip_count: 1 }
      end
    end

    trait :failed do
      status { "failed" }
      started_at { 5.minutes.ago }
      completed_at { Time.current }
      error_details do
        [{ row: 3, column: "email", message: "メールアドレスの形式が不正です" }]
      end
    end
  end
end
