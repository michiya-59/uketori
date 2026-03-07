# frozen_string_literal: true

require "rails_helper"

RSpec.describe DunningRulePolicy do
  let!(:tenant) { create(:tenant) }
  let!(:dunning_rule) do
    DunningRule.create!(
      tenant: tenant, name: "テスト督促ルール",
      trigger_days_after_due: 30, action_type: "email"
    )
  end

  subject { described_class.new(user, dunning_rule) }

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

  describe "#update?" do
    %w[owner admin accountant].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.update?).to be true
        end
      end
    end

    %w[sales member].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "拒否されること" do
          expect(subject.update?).to be false
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

  describe "#execute?" do
    %w[owner admin accountant].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.execute?).to be true
        end
      end
    end

    %w[sales member].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "拒否されること" do
          expect(subject.execute?).to be false
        end
      end
    end
  end
end
