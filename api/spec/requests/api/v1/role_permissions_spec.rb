# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::RolePermissions", type: :request do
  let!(:tenant) { create(:tenant) }
  let!(:owner) { create(:user, :owner, tenant: tenant) }
  let!(:admin) { create(:user, :admin, tenant: tenant) }
  let!(:accountant) { create(:user, :accountant, tenant: tenant) }
  let!(:sales) { create(:user, :sales, tenant: tenant) }
  let!(:member) { create(:user, :member, tenant: tenant) }

  describe "GET /api/v1/role_permissions" do
    context "ownerの場合" do
      it "全ロールの権限設定が返されること" do
        get "/api/v1/role_permissions", headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["roles"].length).to eq(4) # admin, accountant, sales, member
        expect(body["roles"].map { |r| r["role"] }).to match_array(%w[admin accountant sales member])
        expect(body["resources"]).to be_present
      end

      it "各ロールにデフォルト権限情報が含まれること" do
        get "/api/v1/role_permissions", headers: auth_headers(owner)

        body = response.parsed_body
        admin_role = body["roles"].find { |r| r["role"] == "admin" }
        expect(admin_role["permissions"]).to be_present
        expect(admin_role["permissions"]["customer.create"]["allowed"]).to be true
        expect(admin_role["permissions"]["customer.create"]["default"]).to be true
        expect(admin_role["permissions"]["customer.create"]["customized"]).to be false
      end

      it "リソースメタデータが含まれること" do
        get "/api/v1/role_permissions", headers: auth_headers(owner)

        body = response.parsed_body
        customer_resource = body["resources"].find { |r| r["resource"] == "customer" }
        expect(customer_resource["resource_label"]).to eq("顧客")
        expect(customer_resource["actions"].map { |a| a["action"] }).to include("create", "update", "destroy")
      end
    end

    context "adminの場合" do
      it "権限設定が返されること" do
        get "/api/v1/role_permissions", headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
      end
    end

    context "accountantの場合" do
      it "403エラーが返されること" do
        get "/api/v1/role_permissions", headers: auth_headers(accountant)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "salesの場合" do
      it "403エラーが返されること" do
        get "/api/v1/role_permissions", headers: auth_headers(sales)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "memberの場合" do
      it "403エラーが返されること" do
        get "/api/v1/role_permissions", headers: auth_headers(member)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "未認証の場合" do
      it "401エラーが返されること" do
        get "/api/v1/role_permissions"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "カスタム権限が設定されている場合" do
      before do
        RolePermission.create!(
          tenant: tenant,
          role: "member",
          permissions: { "customer.create" => true }
        )
      end

      it "カスタム設定が反映されること" do
        get "/api/v1/role_permissions", headers: auth_headers(owner)

        body = response.parsed_body
        member_role = body["roles"].find { |r| r["role"] == "member" }
        perm = member_role["permissions"]["customer.create"]
        expect(perm["allowed"]).to be true
        expect(perm["default"]).to be false
        expect(perm["customized"]).to be true
      end
    end
  end

  describe "PUT /api/v1/role_permissions/:id" do
    context "ownerがsalesロールの権限を編集する場合" do
      it "権限が保存されること" do
        put "/api/v1/role_permissions/sales",
            params: { permissions: { "document.approve" => true, "document.lock" => true } },
            headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["role_permission"]["role"]).to eq("sales")
        expect(body["role_permission"]["permissions"]["document.approve"]["allowed"]).to be true
        expect(body["role_permission"]["permissions"]["document.approve"]["customized"]).to be true
      end

      it "DBに保存されていること" do
        put "/api/v1/role_permissions/sales",
            params: { permissions: { "document.approve" => true } },
            headers: auth_headers(owner)

        rp = RolePermission.find_by(tenant: tenant, role: "sales")
        expect(rp).to be_present
        expect(rp.permissions["document.approve"]).to be true
      end
    end

    context "ownerがadminロールの権限を編集する場合" do
      it "権限が保存されること" do
        put "/api/v1/role_permissions/admin",
            params: { permissions: { "user.create" => false } },
            headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
      end
    end

    context "adminがaccountantロールの権限を編集する場合" do
      it "権限が保存されること" do
        put "/api/v1/role_permissions/accountant",
            params: { permissions: { "document.approve" => false } },
            headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
      end
    end

    context "adminがadminロールの権限を編集しようとする場合" do
      it "403エラーが返されること" do
        put "/api/v1/role_permissions/admin",
            params: { permissions: { "user.create" => false } },
            headers: auth_headers(admin)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "adminがownerロールの権限を編集しようとする場合" do
      it "422エラーが返されること（EDITABLE_ROLESに含まれない）" do
        put "/api/v1/role_permissions/owner",
            params: { permissions: {} },
            headers: auth_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "accountantが権限を編集しようとする場合" do
      it "403エラーが返されること" do
        put "/api/v1/role_permissions/member",
            params: { permissions: { "customer.create" => true } },
            headers: auth_headers(accountant)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "無効な権限キーが含まれる場合" do
      it "422エラーが返されること" do
        put "/api/v1/role_permissions/sales",
            params: { permissions: { "invalid.key" => true } },
            headers: auth_headers(owner)

        expect(response).to have_http_status(:unprocessable_entity)
        body = response.parsed_body
        expect(body["error"]["message"]).to include("無効な権限キー")
      end
    end

    context "存在しないロールを指定した場合" do
      it "422エラーが返されること" do
        put "/api/v1/role_permissions/superuser",
            params: { permissions: {} },
            headers: auth_headers(owner)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "既存のカスタム権限を更新する場合" do
      before do
        RolePermission.create!(
          tenant: tenant,
          role: "member",
          permissions: { "customer.create" => true }
        )
      end

      it "既存設定が上書きされること" do
        put "/api/v1/role_permissions/member",
            params: { permissions: { "document.create" => true } },
            headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        rp = RolePermission.find_by(tenant: tenant, role: "member")
        # 新しいpermissionsで完全に置き換え
        expect(rp.permissions).to eq({ "document.create" => true })
      end
    end

    context "他テナントの権限に影響しないこと" do
      let!(:other_tenant) { create(:tenant) }
      let!(:other_owner) { create(:user, :owner, tenant: other_tenant) }

      before do
        RolePermission.create!(
          tenant: other_tenant,
          role: "sales",
          permissions: { "customer.destroy" => true }
        )
      end

      it "自テナントの更新が他テナントに影響しないこと" do
        put "/api/v1/role_permissions/sales",
            params: { permissions: { "customer.destroy" => false } },
            headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)

        other_rp = RolePermission.find_by(tenant: other_tenant, role: "sales")
        expect(other_rp.permissions["customer.destroy"]).to be true
      end
    end
  end

  describe "POST /api/v1/role_permissions/:id/reset" do
    context "カスタム権限が存在する場合" do
      before do
        RolePermission.create!(
          tenant: tenant,
          role: "sales",
          permissions: { "document.approve" => true, "customer.destroy" => true }
        )
      end

      context "ownerがリセットする場合" do
        it "カスタム権限が削除されること" do
          post "/api/v1/role_permissions/sales/reset", headers: auth_headers(owner)

          expect(response).to have_http_status(:ok)
          expect(RolePermission.find_by(tenant: tenant, role: "sales")).to be_nil
        end

        it "デフォルト値が返されること" do
          post "/api/v1/role_permissions/sales/reset", headers: auth_headers(owner)

          body = response.parsed_body
          perm = body["role_permission"]["permissions"]["document.approve"]
          expect(perm["allowed"]).to be false # salesのデフォルト
          expect(perm["customized"]).to be false
        end
      end

      context "adminがsalesロールをリセットする場合" do
        it "権限が削除されること" do
          post "/api/v1/role_permissions/sales/reset", headers: auth_headers(admin)

          expect(response).to have_http_status(:ok)
          expect(RolePermission.find_by(tenant: tenant, role: "sales")).to be_nil
        end
      end

      context "adminがadminロールをリセットしようとする場合" do
        before do
          RolePermission.create!(
            tenant: tenant,
            role: "admin",
            permissions: { "user.create" => false }
          )
        end

        it "403エラーが返されること" do
          post "/api/v1/role_permissions/admin/reset", headers: auth_headers(admin)

          expect(response).to have_http_status(:forbidden)
          # 権限が削除されていないことを確認
          expect(RolePermission.find_by(tenant: tenant, role: "admin")).to be_present
        end
      end
    end

    context "カスタム権限が存在しない場合" do
      it "正常にレスポンスされること（冪等）" do
        post "/api/v1/role_permissions/sales/reset", headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "カスタム権限が実際のポリシー判定に反映されること（統合テスト）" do
    context "memberに顧客作成権限を付与してAPIアクセスする場合" do
      before do
        RolePermission.create!(
          tenant: tenant,
          role: "member",
          permissions: { "customer.create" => true }
        )
      end

      it "memberが顧客を作成できること" do
        post "/api/v1/customers",
             params: { customer: { company_name: "テスト顧客" } },
             headers: auth_headers(member)

        # 403ではなく、作成処理に進む（バリデーションエラーでも403でないことが重要）
        expect(response.status).not_to eq(403)
      end
    end

    context "カスタム権限なしでmemberが顧客を作成しようとする場合" do
      it "403エラーが返されること" do
        post "/api/v1/customers",
             params: { customer: { company_name: "テスト顧客" } },
             headers: auth_headers(member)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
