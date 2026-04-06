# frozen_string_literal: true

require "rails_helper"

RSpec.describe "カスタム権限によるポリシー上書き", type: :policy do
  let!(:tenant) { create(:tenant) }
  let!(:owner_user) { create(:user, :owner, tenant: tenant) }
  let!(:admin_user) { create(:user, :admin, tenant: tenant) }
  let!(:accountant_user) { create(:user, :accountant, tenant: tenant) }
  let!(:sales_user) { create(:user, :sales, tenant: tenant) }
  let!(:member_user) { create(:user, :member, tenant: tenant) }

  # ダミーレコード（ポリシーのrecordに使うもの）
  let!(:customer) { Customer.new(tenant: tenant) }
  let!(:product) { Product.new(tenant: tenant) }
  let!(:project) { Project.new(tenant: tenant) }
  let!(:document_record) { Document.new(tenant: tenant) }
  let!(:payment_record) { PaymentRecord.new(tenant: tenant) }

  describe "デフォルト権限（カスタマイズなし）" do
    context "ownerロールの場合" do
      it "全てのアクションが許可されること" do
        expect(CustomerPolicy.new(owner_user, customer).create?).to be true
        expect(CustomerPolicy.new(owner_user, customer).destroy?).to be true
        expect(DocumentPolicy.new(owner_user, document_record).approve?).to be true
        expect(UserPolicy.new(owner_user, member_user).destroy?).to be true
        expect(ImportJobPolicy.new(owner_user, nil).create?).to be true
      end
    end

    context "adminロールの場合" do
      it "admin以上のアクションが許可されること" do
        expect(CustomerPolicy.new(admin_user, customer).create?).to be true
        expect(CustomerPolicy.new(admin_user, customer).destroy?).to be true
        expect(UserPolicy.new(admin_user, member_user).create?).to be true
        expect(UserPolicy.new(admin_user, member_user).destroy?).to be true
        expect(ImportJobPolicy.new(admin_user, nil).create?).to be true
      end
    end

    context "accountantロールの場合" do
      it "accountant以上のアクションが許可されること" do
        expect(CustomerPolicy.new(accountant_user, customer).create?).to be true
        expect(DocumentPolicy.new(accountant_user, document_record).approve?).to be true
        expect(PaymentRecordPolicy.new(accountant_user, payment_record).create?).to be true
      end

      it "admin限定のアクションが拒否されること" do
        expect(CustomerPolicy.new(accountant_user, customer).destroy?).to be false
        expect(UserPolicy.new(accountant_user, member_user).create?).to be false
        expect(ImportJobPolicy.new(accountant_user, nil).create?).to be false
      end
    end

    context "salesロールの場合" do
      it "sales以上のアクションが許可されること" do
        expect(CustomerPolicy.new(sales_user, customer).create?).to be true
        expect(DocumentPolicy.new(sales_user, document_record).create?).to be true
        expect(ProjectPolicy.new(sales_user, project).status?).to be true
      end

      it "accountant以上のアクションが拒否されること" do
        expect(DocumentPolicy.new(sales_user, document_record).approve?).to be false
        expect(PaymentRecordPolicy.new(sales_user, payment_record).create?).to be false
      end

      it "admin限定のアクションが拒否されること" do
        expect(CustomerPolicy.new(sales_user, customer).destroy?).to be false
        expect(UserPolicy.new(sales_user, member_user).create?).to be false
      end
    end

    context "memberロールの場合" do
      it "閲覧系のアクションが許可されること" do
        expect(CustomerPolicy.new(member_user, customer).index?).to be true
        expect(CustomerPolicy.new(member_user, customer).show?).to be true
        expect(DocumentPolicy.new(member_user, document_record).index?).to be true
        expect(DocumentPolicy.new(member_user, document_record).pdf?).to be true
      end

      it "全ての書き込みアクションが拒否されること" do
        expect(CustomerPolicy.new(member_user, customer).create?).to be false
        expect(CustomerPolicy.new(member_user, customer).update?).to be false
        expect(CustomerPolicy.new(member_user, customer).destroy?).to be false
        expect(DocumentPolicy.new(member_user, document_record).create?).to be false
        expect(DocumentPolicy.new(member_user, document_record).approve?).to be false
        expect(UserPolicy.new(member_user, member_user).create?).to be false
      end
    end
  end

  describe "カスタム権限による権限昇格（拒否→許可）" do
    context "memberに顧客作成権限を付与した場合" do
      before do
        RolePermission.create!(
          tenant: tenant,
          role: "member",
          permissions: { "customer.create" => true }
        )
      end

      it "memberが顧客を作成できること" do
        expect(CustomerPolicy.new(member_user, customer).create?).to be true
      end

      it "他の権限は変わらないこと" do
        expect(CustomerPolicy.new(member_user, customer).update?).to be false
        expect(CustomerPolicy.new(member_user, customer).destroy?).to be false
        expect(DocumentPolicy.new(member_user, document_record).create?).to be false
      end
    end

    context "salesに帳票承認権限を付与した場合" do
      before do
        RolePermission.create!(
          tenant: tenant,
          role: "sales",
          permissions: { "document.approve" => true, "document.reject" => true }
        )
      end

      it "salesが帳票を承認・却下できること" do
        expect(DocumentPolicy.new(sales_user, document_record).approve?).to be true
        expect(DocumentPolicy.new(sales_user, document_record).reject?).to be true
      end

      it "既存の権限は維持されること" do
        expect(DocumentPolicy.new(sales_user, document_record).create?).to be true
        expect(DocumentPolicy.new(sales_user, document_record).send_document?).to be true
      end
    end

    context "memberに複数の権限を一括付与した場合" do
      before do
        RolePermission.create!(
          tenant: tenant,
          role: "member",
          permissions: {
            "customer.create" => true,
            "customer.update" => true,
            "document.create" => true,
            "document.update" => true,
            "project.create" => true
          }
        )
      end

      it "付与された全ての権限が有効になること" do
        expect(CustomerPolicy.new(member_user, customer).create?).to be true
        expect(CustomerPolicy.new(member_user, customer).update?).to be true
        expect(DocumentPolicy.new(member_user, document_record).create?).to be true
        expect(DocumentPolicy.new(member_user, document_record).update?).to be true
        expect(ProjectPolicy.new(member_user, project).create?).to be true
      end

      it "付与されていない権限は拒否のままであること" do
        expect(CustomerPolicy.new(member_user, customer).destroy?).to be false
        expect(DocumentPolicy.new(member_user, document_record).approve?).to be false
        expect(UserPolicy.new(member_user, member_user).create?).to be false
      end
    end
  end

  describe "カスタム権限による権限降格（許可→拒否）" do
    context "adminからユーザー管理権限を剥奪した場合" do
      before do
        RolePermission.create!(
          tenant: tenant,
          role: "admin",
          permissions: { "user.create" => false, "user.invite" => false, "user.destroy" => false }
        )
      end

      it "adminがユーザー作成・招待・削除できないこと" do
        expect(UserPolicy.new(admin_user, member_user).create?).to be false
        expect(UserPolicy.new(admin_user, User).invite?).to be false
        expect(UserPolicy.new(admin_user, member_user).destroy?).to be false
      end

      it "他の権限は維持されること" do
        expect(CustomerPolicy.new(admin_user, customer).destroy?).to be true
        expect(ImportJobPolicy.new(admin_user, nil).create?).to be true
      end
    end

    context "accountantから帳票承認権限を剥奪した場合" do
      before do
        RolePermission.create!(
          tenant: tenant,
          role: "accountant",
          permissions: { "document.approve" => false, "document.lock" => false }
        )
      end

      it "accountantが帳票を承認・ロックできないこと" do
        expect(DocumentPolicy.new(accountant_user, document_record).approve?).to be false
        expect(DocumentPolicy.new(accountant_user, document_record).lock?).to be false
      end

      it "他のaccountant権限は維持されること" do
        expect(DocumentPolicy.new(accountant_user, document_record).reject?).to be true
        expect(PaymentRecordPolicy.new(accountant_user, payment_record).create?).to be true
      end
    end
  end

  describe "ownerは常にカスタム権限の影響を受けないこと" do
    before do
      # ownerはEDITABLE_ROLESに含まれないので直接カスタムは作れないが、
      # check_permissionの先頭でowner判定される
      RolePermission.create!(
        tenant: tenant,
        role: "admin",
        permissions: RolePermission::DEFAULT_MIN_ROLES.keys.each_with_object({}) { |k, h| h[k] = false }
      )
    end

    it "ownerは全権限が許可のままであること" do
      expect(CustomerPolicy.new(owner_user, customer).create?).to be true
      expect(CustomerPolicy.new(owner_user, customer).destroy?).to be true
      expect(DocumentPolicy.new(owner_user, document_record).approve?).to be true
      expect(UserPolicy.new(owner_user, member_user).destroy?).to be true
      expect(ImportJobPolicy.new(owner_user, nil).create?).to be true
    end
  end

  describe "テナント間の権限分離" do
    let!(:other_tenant) { create(:tenant) }
    let!(:other_member) { create(:user, :member, tenant: other_tenant) }

    before do
      RolePermission.create!(
        tenant: tenant,
        role: "member",
        permissions: { "customer.create" => true }
      )
    end

    it "カスタム権限は設定したテナントのユーザーにのみ適用されること" do
      other_customer = Customer.new(tenant: other_tenant)
      expect(CustomerPolicy.new(member_user, customer).create?).to be true
      expect(CustomerPolicy.new(other_member, other_customer).create?).to be false
    end
  end

  describe "UserPolicyのビジネスロジック制約はカスタム権限で上書きできないこと" do
    context "カスタム権限でmemberにuser.destroy権限を付与しても" do
      before do
        RolePermission.create!(
          tenant: tenant,
          role: "member",
          permissions: { "user.destroy" => true }
        )
      end

      it "自分自身は削除できないこと" do
        expect(UserPolicy.new(member_user, member_user).destroy?).to be false
      end

      it "ownerは削除できないこと" do
        expect(UserPolicy.new(member_user, owner_user).destroy?).to be false
      end

      it "他のメンバーは削除できること" do
        other_member = create(:user, :member, tenant: tenant)
        expect(UserPolicy.new(member_user, other_member).destroy?).to be true
      end
    end

    context "カスタム権限でmemberにuser.update権限を付与しても" do
      before do
        RolePermission.create!(
          tenant: tenant,
          role: "member",
          permissions: { "user.update" => true }
        )
      end

      it "ownerの情報は更新できないこと（owner以外）" do
        expect(UserPolicy.new(member_user, owner_user).update?).to be false
      end

      it "他のメンバーは更新できること" do
        other_member = create(:user, :member, tenant: tenant)
        expect(UserPolicy.new(member_user, other_member).update?).to be true
      end
    end
  end

  describe "全ポリシー×全ロール×デフォルト権限の網羅テスト" do
    # 各ポリシーのcheck_permissionを使うアクションを全て検証
    POLICY_PERMISSION_MAP = {
      CustomerPolicy => {
        record_builder: -> (tenant) { Customer.new(tenant: tenant) },
        actions: {
          "create?" => { resource: "customer", action: "create", default_min: "sales" },
          "update?" => { resource: "customer", action: "update", default_min: "sales" },
          "destroy?" => { resource: "customer", action: "destroy", default_min: "admin" },
          "credit_history?" => { resource: "customer", action: "credit_history", default_min: "accountant" },
          "verify_invoice_number?" => { resource: "customer", action: "verify_invoice_number", default_min: "sales" }
        }
      },
      ProductPolicy => {
        record_builder: -> (tenant) { Product.new(tenant: tenant) },
        actions: {
          "create?" => { resource: "product", action: "create", default_min: "accountant" },
          "update?" => { resource: "product", action: "update", default_min: "accountant" },
          "destroy?" => { resource: "product", action: "destroy", default_min: "admin" }
        }
      },
      ProjectPolicy => {
        record_builder: -> (tenant) { Project.new(tenant: tenant) },
        actions: {
          "create?" => { resource: "project", action: "create", default_min: "sales" },
          "update?" => { resource: "project", action: "update", default_min: "sales" },
          "destroy?" => { resource: "project", action: "destroy", default_min: "admin" },
          "status?" => { resource: "project", action: "status", default_min: "sales" }
        }
      },
      DocumentPolicy => {
        record_builder: -> (tenant) { Document.new(tenant: tenant) },
        actions: {
          "create?" => { resource: "document", action: "create", default_min: "sales" },
          "update?" => { resource: "document", action: "update", default_min: "sales" },
          "destroy?" => { resource: "document", action: "destroy", default_min: "admin" },
          "duplicate?" => { resource: "document", action: "duplicate", default_min: "sales" },
          "convert?" => { resource: "document", action: "convert", default_min: "sales" },
          "approve?" => { resource: "document", action: "approve", default_min: "accountant" },
          "reject?" => { resource: "document", action: "reject", default_min: "accountant" },
          "send_document?" => { resource: "document", action: "send_document", default_min: "sales" },
          "lock?" => { resource: "document", action: "lock", default_min: "accountant" },
          "bulk_generate?" => { resource: "document", action: "bulk_generate", default_min: "accountant" },
          "ai_suggest?" => { resource: "document", action: "ai_suggest", default_min: "sales" }
        }
      },
      PaymentRecordPolicy => {
        record_builder: -> (tenant) { PaymentRecord.new(tenant: tenant) },
        actions: {
          "create?" => { resource: "payment_record", action: "create", default_min: "accountant" },
          "destroy?" => { resource: "payment_record", action: "destroy", default_min: "admin" }
        }
      },
      DunningRulePolicy => {
        record_builder: -> (tenant) { DunningRule.new(tenant: tenant) },
        actions: {
          "create?" => { resource: "dunning_rule", action: "create", default_min: "accountant" },
          "update?" => { resource: "dunning_rule", action: "update", default_min: "accountant" },
          "destroy?" => { resource: "dunning_rule", action: "destroy", default_min: "admin" },
          "execute?" => { resource: "dunning_rule", action: "execute", default_min: "accountant" }
        }
      },
      TenantPolicy => {
        record_builder: -> (tenant) { tenant },
        actions: {
          "update?" => { resource: "tenant", action: "update", default_min: "admin" }
        }
      }
    }.freeze

    POLICY_PERMISSION_MAP.each do |policy_class, config|
      describe policy_class.name do
        let!(:record) { config[:record_builder].call(tenant) }

        config[:actions].each do |method_name, perm_config|
          describe "##{method_name}" do
            roles_and_users = {
              "owner" => :owner_user,
              "admin" => :admin_user,
              "accountant" => :accountant_user,
              "sales" => :sales_user,
              "member" => :member_user
            }

            roles_and_users.each do |role, user_var|
              context "#{role}ロール（デフォルト権限）の場合" do
                it "デフォルトの最低ロール（#{perm_config[:default_min]}）に基づいて判定されること" do
                  user = send(user_var)
                  policy = policy_class.new(user, record)
                  expected = role == "owner" || User::ROLES.index(role) <= User::ROLES.index(perm_config[:default_min])
                  expect(policy.send(method_name)).to eq(expected),
                    "#{policy_class}##{method_name} for #{role}: expected #{expected}"
                end
              end
            end
          end
        end
      end
    end
  end
end
