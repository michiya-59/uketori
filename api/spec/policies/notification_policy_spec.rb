# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationPolicy do
  let!(:tenant) { create(:tenant) }
  let!(:user) { create(:user, tenant: tenant, role: "member") }
  let!(:other_user) { create(:user, tenant: tenant, role: "member") }
  let!(:notification) do
    Notification.create!(
      tenant: tenant, user: user,
      title: "テスト通知",
      notification_type: "info"
    )
  end

  describe "#index?" do
    subject { described_class.new(user, notification) }

    %w[owner admin accountant sales member].each do |role|
      context "#{role}ロールの場合" do
        let!(:user) { create(:user, tenant: tenant, role: role) }
        let!(:notification) do
          Notification.create!(
            tenant: tenant, user: user,
            title: "テスト通知",
            notification_type: "info"
          )
        end

        it "許可されること" do
          expect(subject.index?).to be true
        end
      end
    end
  end

  describe "#update?" do
    context "自分の通知の場合" do
      subject { described_class.new(user, notification) }

      it "許可されること" do
        expect(subject.update?).to be true
      end
    end

    context "他人の通知の場合" do
      subject { described_class.new(other_user, notification) }

      it "拒否されること" do
        expect(subject.update?).to be false
      end
    end
  end
end
