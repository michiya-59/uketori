# frozen_string_literal: true

require "rails_helper"

RSpec.describe CustomerPolicy do
  let!(:tenant) { create(:tenant) }
  let!(:customer) { create(:customer, tenant: tenant) }

  subject { described_class.new(user, customer) }

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

  describe "#documents?" do
    %w[owner admin accountant sales member].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.documents?).to be true
        end
      end
    end
  end

  describe "#credit_history?" do
    %w[owner admin accountant].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.credit_history?).to be true
        end
      end
    end

    %w[sales member].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "拒否されること" do
          expect(subject.credit_history?).to be false
        end
      end
    end
  end

  describe "#verify_invoice_number?" do
    %w[owner admin accountant sales].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.verify_invoice_number?).to be true
        end
      end
    end

    context "memberロールの場合" do
      let!(:user) { create(:user, tenant: tenant, role: "member") }

      it "拒否されること" do
        expect(subject.verify_invoice_number?).to be false
      end
    end
  end
end
