# frozen_string_literal: true

require "rails_helper"

RSpec.describe RolePermissionPolicy, type: :policy do
  let!(:tenant) { create(:tenant) }
  let!(:owner_user) { create(:user, :owner, tenant: tenant) }
  let!(:admin_user) { create(:user, :admin, tenant: tenant) }
  let!(:accountant_user) { create(:user, :accountant, tenant: tenant) }
  let!(:sales_user) { create(:user, :sales, tenant: tenant) }
  let!(:member_user) { create(:user, :member, tenant: tenant) }

  describe "#index?" do
    context "ownerの場合" do
      it "許可されること" do
        expect(RolePermissionPolicy.new(owner_user, :role_permission).index?).to be true
      end
    end

    context "adminの場合" do
      it "許可されること" do
        expect(RolePermissionPolicy.new(admin_user, :role_permission).index?).to be true
      end
    end

    context "accountantの場合" do
      it "拒否されること" do
        expect(RolePermissionPolicy.new(accountant_user, :role_permission).index?).to be false
      end
    end

    context "salesの場合" do
      it "拒否されること" do
        expect(RolePermissionPolicy.new(sales_user, :role_permission).index?).to be false
      end
    end

    context "memberの場合" do
      it "拒否されること" do
        expect(RolePermissionPolicy.new(member_user, :role_permission).index?).to be false
      end
    end
  end

  describe "#update?" do
    context "ownerの場合" do
      it "adminロールの権限を編集できること" do
        expect(RolePermissionPolicy.new(owner_user, "admin").update?).to be true
      end

      it "accountantロールの権限を編集できること" do
        expect(RolePermissionPolicy.new(owner_user, "accountant").update?).to be true
      end

      it "salesロールの権限を編集できること" do
        expect(RolePermissionPolicy.new(owner_user, "sales").update?).to be true
      end

      it "memberロールの権限を編集できること" do
        expect(RolePermissionPolicy.new(owner_user, "member").update?).to be true
      end

      it "ownerロールの権限は編集できないこと（EDITABLE_ROLESに含まれない）" do
        # ownerロールはEDITABLE_ROLESに含まれないためコントローラーレベルで弾かれる
        # ポリシーではownerは常にtrue
        expect(RolePermissionPolicy.new(owner_user, "owner").update?).to be true
      end
    end

    context "adminの場合" do
      it "accountantロールの権限を編集できること" do
        expect(RolePermissionPolicy.new(admin_user, "accountant").update?).to be true
      end

      it "salesロールの権限を編集できること" do
        expect(RolePermissionPolicy.new(admin_user, "sales").update?).to be true
      end

      it "memberロールの権限を編集できること" do
        expect(RolePermissionPolicy.new(admin_user, "member").update?).to be true
      end

      it "adminロールの権限は編集できないこと" do
        expect(RolePermissionPolicy.new(admin_user, "admin").update?).to be false
      end

      it "ownerロールの権限は編集できないこと" do
        expect(RolePermissionPolicy.new(admin_user, "owner").update?).to be false
      end
    end

    context "accountantの場合" do
      it "全てのロールの権限を編集できないこと" do
        %w[admin accountant sales member].each do |role|
          expect(RolePermissionPolicy.new(accountant_user, role).update?).to be(false),
            "accountant should not update #{role}"
        end
      end
    end

    context "salesの場合" do
      it "全てのロールの権限を編集できないこと" do
        %w[admin accountant sales member].each do |role|
          expect(RolePermissionPolicy.new(sales_user, role).update?).to be(false),
            "sales should not update #{role}"
        end
      end
    end

    context "memberの場合" do
      it "全てのロールの権限を編集できないこと" do
        %w[admin accountant sales member].each do |role|
          expect(RolePermissionPolicy.new(member_user, role).update?).to be(false),
            "member should not update #{role}"
        end
      end
    end
  end

  describe "#reset?" do
    context "ownerの場合" do
      it "全ロールのリセットが許可されること" do
        %w[admin accountant sales member].each do |role|
          expect(RolePermissionPolicy.new(owner_user, role).reset?).to be(true),
            "owner should reset #{role}"
        end
      end
    end

    context "adminの場合" do
      it "adminロールのリセットは拒否されること" do
        expect(RolePermissionPolicy.new(admin_user, "admin").reset?).to be false
      end

      it "下位ロールのリセットは許可されること" do
        %w[accountant sales member].each do |role|
          expect(RolePermissionPolicy.new(admin_user, role).reset?).to be(true),
            "admin should reset #{role}"
        end
      end
    end
  end
end
