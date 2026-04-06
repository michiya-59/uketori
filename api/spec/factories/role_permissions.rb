# frozen_string_literal: true

FactoryBot.define do
  factory :role_permission do
    tenant
    role { "member" }
    permissions { {} }

    trait :member_with_create do
      role { "member" }
      permissions { { "customer.create" => true, "document.create" => true } }
    end

    trait :sales_with_approve do
      role { "sales" }
      permissions { { "document.approve" => true, "document.reject" => true } }
    end

    trait :admin_restricted do
      role { "admin" }
      permissions { { "user.create" => false, "user.invite" => false } }
    end
  end
end
