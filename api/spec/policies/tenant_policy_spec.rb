# frozen_string_literal: true

require "rails_helper"

RSpec.describe TenantPolicy do
  let!(:tenant) { create(:tenant) }

  subject { described_class.new(user, tenant) }

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

  describe "#update?" do
    context "ownerロールの場合" do
      let!(:user) { create(:user, tenant: tenant, role: "owner") }

      it "許可されること" do
        expect(subject.update?).to be true
      end
    end

    context "adminロールの場合" do
      let!(:user) { create(:user, tenant: tenant, role: "admin") }

      it "許可されること" do
        expect(subject.update?).to be true
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
end
