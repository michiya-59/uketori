# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProjectPolicy do
  let!(:tenant) { create(:tenant) }
  let!(:customer) { create(:customer, tenant: tenant) }
  let!(:project) do
    Project.create!(
      tenant: tenant, customer: customer,
      name: "テストプロジェクト", status: "negotiation",
      project_number: "PRJ-001",
      uuid: SecureRandom.uuid
    )
  end

  subject { described_class.new(user, project) }

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

  describe "#status?" do
    %w[owner admin accountant sales].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.status?).to be true
        end
      end
    end

    context "memberロールの場合" do
      let!(:user) { create(:user, tenant: tenant, role: "member") }

      it "拒否されること" do
        expect(subject.status?).to be false
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

  describe "#pipeline?" do
    %w[owner admin accountant sales member].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.pipeline?).to be true
        end
      end
    end
  end
end
