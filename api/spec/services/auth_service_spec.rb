# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuthService do
  let!(:industry_template) { create(:industry_template, code: "general", name: "汎用") }
  let!(:tenant) { create(:tenant, plan: "free") }
  let!(:owner_user) { create(:user, :owner, tenant: tenant) }

  describe ".sign_up" do
    let(:valid_params) do
      {
        tenant_name: "新規会社",
        industry_code: "general",
        name: "オーナー",
        email: "owner@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      }
    end

    it "テナントとオーナーユーザーとトークンを作成すること" do
      result = described_class.sign_up(valid_params)

      expect(result[:tenant].name).to eq("新規会社")
      expect(result[:user].role).to eq("owner")
      expect(result[:tokens][:access_token]).to be_present
    end

    it "存在しない業種コードではRegistrationErrorになること" do
      expect {
        described_class.sign_up(valid_params.merge(industry_code: "missing"))
      }.to raise_error(AuthService::RegistrationError, /industry_typeが不正/)
    end
  end

  describe ".invite_user" do
    context "プラン上限に達していない場合" do
      it "ユーザーが作成されること" do
        expect {
          described_class.invite_user(
            owner_user,
            { email: "new@example.com", name: "新規ユーザー", role: "member" }
          )
        }.to change(User, :count).by(1)
      end

      it "招待メールが送信されること" do
        expect {
          described_class.invite_user(
            owner_user,
            { email: "new@example.com", name: "新規ユーザー", role: "member" }
          )
        }.to have_enqueued_mail(AuthMailer, :invitation)
      end

      it "招待トークンが設定されること" do
        user = described_class.invite_user(
          owner_user,
          { email: "new@example.com", name: "新規ユーザー", role: "member" }
        )
        expect(user.invitation_token).to be_present
        expect(user.invitation_sent_at).to be_present
      end
    end

    context "freeプランでユーザー数上限（3人）に達している場合" do
      before do
        # owner_userで1人、追加で2人作成して合計3人
        create_list(:user, 2, tenant: tenant, role: "member")
      end

      it "PlanLimitErrorが発生すること" do
        expect {
          described_class.invite_user(
            owner_user,
            { email: "excess@example.com", name: "超過ユーザー", role: "member" }
          )
        }.to raise_error(AuthService::PlanLimitError, /freeプランのユーザー数上限/)
      end
    end

    context "standardプランの場合" do
      before { tenant.update!(plan: "standard") }

      it "10人まで招待できること" do
        # owner_userで1人、追加で8人作成して合計9人 (10人目を招待)
        create_list(:user, 8, tenant: tenant, role: "member")

        expect {
          described_class.invite_user(
            owner_user,
            { email: "tenth@example.com", name: "10人目", role: "member" }
          )
        }.to change(User, :count).by(1)
      end
    end

    context "professionalプランの場合" do
      before { tenant.update!(plan: "professional") }

      it "ユーザー数制限がないこと" do
        create_list(:user, 10, tenant: tenant, role: "member")

        expect {
          described_class.invite_user(
            owner_user,
            { email: "unlimited@example.com", name: "無制限", role: "member" }
          )
        }.to change(User, :count).by(1)
      end
    end

    context "論理削除されたユーザーがいる場合" do
      before do
        create_list(:user, 2, tenant: tenant, role: "member")
        tenant.users.where(role: "member").first.update!(deleted_at: Time.current)
      end

      it "論理削除されたユーザーはカウントに含まれないこと" do
        # owner + 2 members - 1 deleted = 2 active users (< 3 limit)
        expect {
          described_class.invite_user(
            owner_user,
            { email: "new@example.com", name: "新規ユーザー", role: "member" }
          )
        }.to change(User, :count).by(1)
      end
    end
  end

  describe ".request_password_reset" do
    context "登録済みメールアドレスの場合" do
      it "パスワードリセットメールが送信されること" do
        expect {
          described_class.request_password_reset(owner_user.email)
        }.to have_enqueued_mail(AuthMailer, :password_reset)
      end
    end

    context "存在しないメールアドレスの場合" do
      it "メールが送信されないこと" do
        expect {
          described_class.request_password_reset("nonexistent@example.com")
        }.not_to have_enqueued_mail(AuthMailer, :password_reset)
      end
    end

    context "論理削除されたユーザーの場合" do
      before { owner_user.update!(deleted_at: Time.current) }

      it "メールが送信されないこと" do
        expect {
          described_class.request_password_reset(owner_user.email)
        }.not_to have_enqueued_mail(AuthMailer, :password_reset)
      end
    end
  end

  describe ".reset_password" do
    let!(:reset_token) { owner_user.password_reset_token }

    context "有効なトークンの場合" do
      it "パスワードが更新されること" do
        described_class.reset_password(reset_token, "Newpass123!", "Newpass123!")
        expect(owner_user.reload.authenticate("Newpass123!")).to be_truthy
      end

      it "JWTが無効化されること" do
        old_jti = owner_user.jti
        described_class.reset_password(reset_token, "Newpass123!", "Newpass123!")
        expect(owner_user.reload.jti).not_to eq(old_jti)
      end
    end

    context "無効なトークンの場合" do
      it "AuthenticationErrorが発生すること" do
        expect {
          described_class.reset_password("invalid", "Newpass123!", "Newpass123!")
        }.to raise_error(AuthService::AuthenticationError, /無効なリセットトークン/)
      end
    end
  end

  describe ".accept_invitation" do
    let!(:invited_user) do
      described_class.invite_user(
        owner_user,
        { email: "invited@example.com", name: "招待ユーザー", role: "member" }
      )
    end

    context "有効な招待トークンの場合" do
      it "パスワードが設定されトークンが返されること" do
        result = described_class.accept_invitation(
          invited_user.invitation_token,
          { password: "Newpass123!", password_confirmation: "Newpass123!" }
        )
        expect(result[:user]).to eq(invited_user)
        expect(result[:tokens][:access_token]).to be_present
      end

      it "招待トークンがクリアされること" do
        described_class.accept_invitation(
          invited_user.invitation_token,
          { password: "Newpass123!", password_confirmation: "Newpass123!" }
        )
        expect(invited_user.reload.invitation_token).to be_nil
        expect(invited_user.invitation_accepted_at).to be_present
      end
    end

    context "無効な招待トークンの場合" do
      it "AuthenticationErrorが発生すること" do
        expect {
          described_class.accept_invitation(
            "invalid_token",
            { password: "Newpass123!", password_confirmation: "Newpass123!" }
          )
        }.to raise_error(AuthService::AuthenticationError, /無効な招待トークン/)
      end
    end
  end
end
