# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentRecordPolicy do
  let!(:tenant) { create(:tenant) }
  let!(:owner_user) { create(:user, tenant: tenant, role: "owner") }
  let!(:customer) { create(:customer, tenant: tenant) }
  let!(:document) do
    Document.create!(
      tenant: tenant, customer: customer,
      created_by_user_id: owner_user.id,
      document_type: "invoice", status: "sent",
      document_number: "INV-0001",
      issue_date: Date.current, uuid: SecureRandom.uuid
    )
  end
  let!(:payment_record) do
    PaymentRecord.create!(
      tenant: tenant, document: document,
      amount: 10_000, payment_date: Date.current,
      payment_method: "bank_transfer",
      recorded_by_user_id: owner_user.id,
      uuid: SecureRandom.uuid
    )
  end

  subject { described_class.new(user, payment_record) }

  describe "#index?" do
    %w[owner admin accountant sales member].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.index?).to be true
        end
      end
    end
  end

  describe "#create?" do
    %w[owner admin accountant].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.create?).to be true
        end
      end
    end

    %w[sales member].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "拒否されること" do
          expect(subject.create?).to be false
        end
      end
    end
  end

  describe "#destroy?" do
    %w[owner admin].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.destroy?).to be true
        end
      end
    end

    %w[accountant sales member].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "拒否されること" do
          expect(subject.destroy?).to be false
        end
      end
    end
  end
end
