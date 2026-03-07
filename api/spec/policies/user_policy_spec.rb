# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserPolicy do
  let!(:tenant) { create(:tenant) }
  let!(:target_user) { create(:user, tenant: tenant, role: "member") }

  subject { described_class.new(user, target_user) }

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
    %w[owner admin].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.create?).to be true
        end
      end
    end

    %w[accountant sales member].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "拒否されること" do
          expect(subject.create?).to be false
        end
      end
    end
  end

  describe "#invite?" do
    %w[owner admin].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "許可されること" do
          expect(subject.invite?).to be true
        end
      end
    end

    %w[accountant sales member].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "拒否されること" do
          expect(subject.invite?).to be false
        end
      end
    end
  end

  describe "#update?" do
    context "adminが一般ユーザーを更新する場合" do
      let!(:user) { create(:user, tenant: tenant, role: "admin") }

      it "許可されること" do
        expect(subject.update?).to be true
      end
    end

    context "ownerがownerを更新する場合" do
      let!(:user) { create(:user, tenant: tenant, role: "owner") }
      let!(:target_user) { create(:user, tenant: tenant, role: "owner") }

      it "許可されること" do
        expect(subject.update?).to be true
      end
    end

    context "adminがownerを更新する場合" do
      let!(:user) { create(:user, tenant: tenant, role: "admin") }
      let!(:target_user) { create(:user, tenant: tenant, role: "owner") }

      it "拒否されること" do
        expect(subject.update?).to be false
      end
    end

    %w[accountant sales member].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }

        it "拒否されること" do
          expect(subject.update?).to be false
        end
      end
    end
  end

  describe "#destroy?" do
    context "adminが一般ユーザーを削除する場合" do
      let!(:user) { create(:user, tenant: tenant, role: "admin") }

      it "許可されること" do
        expect(subject.destroy?).to be true
      end
    end

    context "adminが自分自身を削除する場合" do
      let!(:user) { create(:user, tenant: tenant, role: "admin") }

      subject { described_class.new(user, user) }

      it "拒否されること" do
        expect(subject.destroy?).to be false
      end
    end

    context "adminがownerを削除する場合" do
      let!(:user) { create(:user, tenant: tenant, role: "admin") }
      let!(:target_user) { create(:user, tenant: tenant, role: "owner") }

      it "拒否されること" do
        expect(subject.destroy?).to be false
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
