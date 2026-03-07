# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    tenant
    user
    notification_type { "payment_overdue" }
    title { "請求書 INV-2026-001 の支払い期限が超過しています" }
    body { "詳細を確認してください。" }
    is_read { false }

    trait :read do
      is_read { true }
      read_at { Time.current }
    end

    trait :import_completed do
      notification_type { "import_completed" }
      title { "データインポートが完了しました" }
      body { "10件のインポートが正常に完了しました。" }
    end

    trait :dunning_sent do
      notification_type { "dunning_sent" }
      title { "督促メールが送信されました" }
      body { "3件の督促メールを送信しました。" }
    end
  end
end
