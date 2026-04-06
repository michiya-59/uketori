# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  let!(:tenant) { create(:tenant) }

  describe "バリデーション" do
    let!(:user) { create(:user, tenant: tenant) }

    context "有効な属性の場合" do
      it "バリデーションが通ること" do
        expect(user).to be_valid
      end
    end

    context "emailが空の場合" do
      it "バリデーションエラーになること" do
        user.email = nil
        expect(user).not_to be_valid
        expect(user.errors[:email]).to be_present
      end
    end

    context "emailの形式が不正な場合" do
      it "バリデーションエラーになること" do
        user.email = "invalid-email"
        expect(user).not_to be_valid
      end
    end

    context "nameが空の場合" do
      it "バリデーションエラーになること" do
        user.name = nil
        expect(user).not_to be_valid
        expect(user.errors[:name]).to be_present
      end
    end

    context "nameが100文字を超える場合" do
      it "バリデーションエラーになること" do
        user.name = "あ" * 101
        expect(user).not_to be_valid
      end
    end

    context "roleが無効な値の場合" do
      it "バリデーションエラーになること" do
        user.role = "invalid_role"
        expect(user).not_to be_valid
      end
    end

    context "jtiが重複する場合" do
      it "バリデーションエラーになること" do
        other_user = build(:user, tenant: tenant, jti: user.jti)
        expect(other_user).not_to be_valid
        expect(other_user.errors[:jti]).to be_present
      end
    end

    context "passwordが複雑性要件を満たさない場合" do
      it "バリデーションエラーになること" do
        weak_user = build(:user, tenant: tenant, password: "password123", password_confirmation: "password123")
        expect(weak_user).not_to be_valid
        expect(weak_user.errors[:password]).to be_present
      end
    end
  end

  describe "コールバック" do
    context "新規作成時" do
      it "jtiが自動生成されること" do
        user = create(:user, tenant: tenant)
        expect(user.jti).to be_present
        expect(user.jti).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
      end
    end
  end

  describe "#owner?" do
    context "roleがownerの場合" do
      let!(:user) { create(:user, :owner, tenant: tenant) }

      it "trueを返すこと" do
        expect(user.owner?).to be true
      end
    end

    context "roleがmemberの場合" do
      let!(:user) { create(:user, :member, tenant: tenant) }

      it "falseを返すこと" do
        expect(user.owner?).to be false
      end
    end
  end

  describe "#has_role_at_least?" do
    let!(:admin_user) { create(:user, :admin, tenant: tenant) }
    let!(:member_user) { create(:user, :member, tenant: tenant) }

    context "adminがaccountant以上か判定する場合" do
      it "trueを返すこと" do
        expect(admin_user.has_role_at_least?("accountant")).to be true
      end
    end

    context "adminがowner以上か判定する場合" do
      it "falseを返すこと" do
        expect(admin_user.has_role_at_least?("owner")).to be false
      end
    end

    context "memberがsales以上か判定する場合" do
      it "falseを返すこと" do
        expect(member_user.has_role_at_least?("sales")).to be false
      end
    end

    context "無効なロールを指定した場合" do
      it "ArgumentErrorが発生すること" do
        expect { admin_user.has_role_at_least?("invalid") }.to raise_error(ArgumentError)
      end
    end
  end

  describe ".by_role" do
    let!(:owner) { create(:user, :owner, tenant: tenant) }
    let!(:member) { create(:user, :member, tenant: tenant) }

    context "ownerロールでフィルタする場合" do
      it "ownerのみ返すこと" do
        result = User.by_role("owner")
        expect(result).to include(owner)
        expect(result).not_to include(member)
      end
    end
  end
end
