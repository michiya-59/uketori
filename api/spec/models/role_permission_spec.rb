# frozen_string_literal: true

require "rails_helper"

RSpec.describe RolePermission, type: :model do
  let!(:tenant) { create(:tenant) }

  describe "バリデーション" do
    context "有効なデータの場合" do
      it "保存できること" do
        rp = RolePermission.new(tenant: tenant, role: "sales", permissions: { "customer.create" => true })
        expect(rp).to be_valid
      end
    end

    context "roleが空の場合" do
      it "バリデーションエラーになること" do
        rp = RolePermission.new(tenant: tenant, role: "", permissions: {})
        expect(rp).not_to be_valid
        expect(rp.errors[:role]).to be_present
      end
    end

    context "roleが無効な値の場合" do
      it "ownerはバリデーションエラーになること" do
        rp = RolePermission.new(tenant: tenant, role: "owner", permissions: {})
        expect(rp).not_to be_valid
      end

      it "存在しないロールはバリデーションエラーになること" do
        rp = RolePermission.new(tenant: tenant, role: "superuser", permissions: {})
        expect(rp).not_to be_valid
      end
    end

    context "同一テナント・同一ロールで重複する場合" do
      let!(:existing) { RolePermission.create!(tenant: tenant, role: "sales", permissions: {}) }

      it "バリデーションエラーになること" do
        rp = RolePermission.new(tenant: tenant, role: "sales", permissions: {})
        expect(rp).not_to be_valid
        expect(rp.errors[:role]).to be_present
      end
    end

    context "異なるテナントなら同一ロールでも許可されること" do
      let!(:other_tenant) { create(:tenant) }
      let!(:existing) { RolePermission.create!(tenant: tenant, role: "sales", permissions: {}) }

      it "保存できること" do
        rp = RolePermission.new(tenant: other_tenant, role: "sales", permissions: {})
        expect(rp).to be_valid
      end
    end

    context "permissionsに無効なキーが含まれる場合" do
      it "バリデーションエラーになること" do
        rp = RolePermission.new(tenant: tenant, role: "sales", permissions: { "invalid.key" => true })
        expect(rp).not_to be_valid
        expect(rp.errors[:permissions].join).to include("無効な権限キー")
      end
    end

    context "permissionsの値がboolean以外の場合" do
      it "バリデーションエラーになること" do
        rp = RolePermission.new(tenant: tenant, role: "sales", permissions: { "customer.create" => "yes" })
        expect(rp).not_to be_valid
        expect(rp.errors[:permissions].join).to include("true/false")
      end
    end

    context "permissionsが空の場合" do
      it "保存できること" do
        rp = RolePermission.new(tenant: tenant, role: "member", permissions: {})
        expect(rp).to be_valid
      end
    end

    context "EDITABLE_ROLESの各ロールが保存できること" do
      RolePermission::EDITABLE_ROLES.each do |role|
        it "#{role}ロールが保存できること" do
          rp = RolePermission.new(tenant: tenant, role: role, permissions: {})
          expect(rp).to be_valid
        end
      end
    end

    context "全ての有効な権限キーが受け入れられること" do
      it "DEFAULT_MIN_ROLESの全キーが有効であること" do
        all_perms = RolePermission::DEFAULT_MIN_ROLES.keys.each_with_object({}) do |key, h|
          h[key] = true
        end
        rp = RolePermission.new(tenant: tenant, role: "admin", permissions: all_perms)
        expect(rp).to be_valid
      end
    end
  end

  describe "#allowed?" do
    let!(:role_permission) do
      RolePermission.create!(
        tenant: tenant,
        role: "sales",
        permissions: { "customer.create" => true, "customer.destroy" => false }
      )
    end

    context "カスタム設定がある場合" do
      it "trueの権限はtrueを返すこと" do
        expect(role_permission.allowed?("customer", "create")).to be true
      end

      it "falseの権限はfalseを返すこと" do
        expect(role_permission.allowed?("customer", "destroy")).to be false
      end
    end

    context "カスタム設定がない場合" do
      it "nilを返すこと" do
        expect(role_permission.allowed?("customer", "update")).to be_nil
      end
    end
  end

  describe ".default_allowed?" do
    context "ownerロールの場合" do
      # ownerはROLES配列の先頭なので全てtrue
      it "全てのアクションが許可されること" do
        RolePermission::DEFAULT_MIN_ROLES.each_key do |key|
          resource, action = key.split(".", 2)
          expect(RolePermission.default_allowed?("owner", resource, action)).to be(true),
            "owner should be allowed #{key}"
        end
      end
    end

    context "adminロールの場合" do
      it "admin以上のアクションが許可されること" do
        expect(RolePermission.default_allowed?("admin", "user", "create")).to be true
        expect(RolePermission.default_allowed?("admin", "customer", "destroy")).to be true
      end

      it "admin以上のアクション全てが許可されること" do
        RolePermission::DEFAULT_MIN_ROLES.each do |key, min_role|
          resource, action = key.split(".", 2)
          expected = User::ROLES.index("admin") <= User::ROLES.index(min_role)
          expect(RolePermission.default_allowed?("admin", resource, action)).to be(expected),
            "admin #{key} expected #{expected}"
        end
      end
    end

    context "accountantロールの場合" do
      it "accountant以上のアクションが許可されること" do
        expect(RolePermission.default_allowed?("accountant", "document", "approve")).to be true
        expect(RolePermission.default_allowed?("accountant", "customer", "create")).to be true
      end

      it "admin限定のアクションが拒否されること" do
        expect(RolePermission.default_allowed?("accountant", "user", "create")).to be false
        expect(RolePermission.default_allowed?("accountant", "customer", "destroy")).to be false
      end
    end

    context "salesロールの場合" do
      it "sales以上のアクションが許可されること" do
        expect(RolePermission.default_allowed?("sales", "customer", "create")).to be true
        expect(RolePermission.default_allowed?("sales", "document", "create")).to be true
      end

      it "accountant限定のアクションが拒否されること" do
        expect(RolePermission.default_allowed?("sales", "document", "approve")).to be false
        expect(RolePermission.default_allowed?("sales", "payment_record", "create")).to be false
      end

      it "admin限定のアクションが拒否されること" do
        expect(RolePermission.default_allowed?("sales", "user", "create")).to be false
      end
    end

    context "memberロールの場合" do
      it "全てのカスタマイズ可能アクションが拒否されること" do
        RolePermission::DEFAULT_MIN_ROLES.each_key do |key|
          resource, action = key.split(".", 2)
          expect(RolePermission.default_allowed?("member", resource, action)).to be(false),
            "member should not be allowed #{key}"
        end
      end
    end
  end

  describe ".valid_permission_key?" do
    it "有効なキーでtrueを返すこと" do
      expect(RolePermission.valid_permission_key?("customer.create")).to be true
      expect(RolePermission.valid_permission_key?("document.approve")).to be true
    end

    it "無効なキーでfalseを返すこと" do
      expect(RolePermission.valid_permission_key?("invalid.action")).to be false
      expect(RolePermission.valid_permission_key?("customer.invalid")).to be false
      expect(RolePermission.valid_permission_key?("")).to be false
    end
  end

  describe ".all_permission_keys" do
    it "DEFAULT_MIN_ROLESの全キーを返すこと" do
      expect(RolePermission.all_permission_keys).to eq(RolePermission::DEFAULT_MIN_ROLES.keys)
    end

    it "全てのキーがvalid_permission_key?でtrueになること" do
      RolePermission.all_permission_keys.each do |key|
        expect(RolePermission.valid_permission_key?(key)).to be(true), "#{key} should be valid"
      end
    end
  end

  describe "CUSTOMIZABLE_PERMISSIONSとDEFAULT_MIN_ROLESの整合性" do
    it "CUSTOMIZABLE_PERMISSIONSの全エントリがDEFAULT_MIN_ROLESに存在すること" do
      RolePermission::CUSTOMIZABLE_PERMISSIONS.each do |resource, actions|
        actions.each do |action|
          key = "#{resource}.#{action}"
          expect(RolePermission::DEFAULT_MIN_ROLES).to have_key(key),
            "#{key} is in CUSTOMIZABLE_PERMISSIONS but not in DEFAULT_MIN_ROLES"
        end
      end
    end

    it "DEFAULT_MIN_ROLESの全エントリがCUSTOMIZABLE_PERMISSIONSに存在すること" do
      RolePermission::DEFAULT_MIN_ROLES.each_key do |key|
        resource, action = key.split(".", 2)
        expect(RolePermission::CUSTOMIZABLE_PERMISSIONS[resource]).to include(action),
          "#{key} is in DEFAULT_MIN_ROLES but not in CUSTOMIZABLE_PERMISSIONS"
      end
    end

    it "DEFAULT_MIN_ROLESの全値が有効なロールであること" do
      RolePermission::DEFAULT_MIN_ROLES.each_value do |role|
        expect(User::ROLES).to include(role), "#{role} is not a valid role"
      end
    end
  end
end
