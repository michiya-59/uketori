# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocumentPolicy do
  let!(:tenant) { create(:tenant) }
  let!(:owner_user) { create(:user, tenant: tenant, role: "owner") }
  let!(:customer) { create(:customer, tenant: tenant) }
  let!(:document) do
    Document.create!(
      tenant: tenant, customer: customer,
      created_by_user_id: owner_user.id,
      document_type: "invoice", status: "draft",
      document_number: "INV-0001",
      issue_date: Date.current, uuid: SecureRandom.uuid
    )
  end

  subject { described_class.new(user, document) }

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

  describe "#show?" do
    %w[owner admin accountant sales member].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.show?).to be true
        end
      end
    end
  end

  describe "#create?" do
    %w[owner admin accountant sales].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.create?).to be true
        end
      end
    end

    context "memberロールの場合" do
      let!(:user) { create(:user, tenant: tenant, role: "member") }

      it "拒否されること" do
        expect(subject.create?).to be false
      end
    end
  end

  describe "#update?" do
    %w[owner admin accountant sales].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.update?).to be true
        end
      end
    end

    context "memberロールの場合" do
      let!(:user) { create(:user, tenant: tenant, role: "member") }

      it "拒否されること" do
        expect(subject.update?).to be false
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

  describe "#approve?" do
    %w[owner admin accountant].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.approve?).to be true
        end
      end
    end

    %w[sales member].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "拒否されること" do
          expect(subject.approve?).to be false
        end
      end
    end
  end

  describe "#reject?" do
    %w[owner admin accountant].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.reject?).to be true
        end
      end
    end

    %w[sales member].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "拒否されること" do
          expect(subject.reject?).to be false
        end
      end
    end
  end

  describe "#duplicate?" do
    %w[owner admin accountant sales].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.duplicate?).to be true
        end
      end
    end

    context "memberロールの場合" do
      let!(:user) { create(:user, tenant: tenant, role: "member") }

      it "拒否されること" do
        expect(subject.duplicate?).to be false
      end
    end
  end

  describe "#convert?" do
    %w[owner admin accountant sales].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.convert?).to be true
        end
      end
    end

    context "memberロールの場合" do
      let!(:user) { create(:user, tenant: tenant, role: "member") }

      it "拒否されること" do
        expect(subject.convert?).to be false
      end
    end
  end

  describe "#lock?" do
    %w[owner admin accountant].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.lock?).to be true
        end
      end
    end

    %w[sales member].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "拒否されること" do
          expect(subject.lock?).to be false
        end
      end
    end
  end

  describe "#pdf?" do
    %w[owner admin accountant sales member].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.pdf?).to be true
        end
      end
    end
  end

  describe "#bulk_generate?" do
    %w[owner admin accountant].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.bulk_generate?).to be true
        end
      end
    end

    %w[sales member].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "拒否されること" do
          expect(subject.bulk_generate?).to be false
        end
      end
    end
  end
end
