# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuthMailer do
  let!(:tenant) { create(:tenant, name: "テスト株式会社") }
  let!(:user) { create(:user, :owner, tenant: tenant, name: "山田太郎", email: "yamada@example.com") }

  describe "#password_reset" do
    let!(:token) { "test_reset_token_123" }
    let!(:mail) { described_class.password_reset(user, token) }

    it "正しい宛先に送信されること" do
      expect(mail.to).to eq(["yamada@example.com"])
    end

    it "正しい件名が設定されること" do
      expect(mail.subject).to eq("【ウケトリ】パスワードリセットのご案内")
    end

    it "本文にユーザー名が含まれること" do
      expect(mail.body.encoded).to include("山田太郎")
    end

    it "本文にリセットURLが含まれること" do
      expect(mail.body.encoded).to include("password/reset?token=test_reset_token_123")
    end
  end

  describe "#invitation" do
    let!(:inviter) { create(:user, :admin, tenant: tenant, name: "管理者") }
    let!(:invited_user) do
      create(:user, tenant: tenant, role: "member", name: "新人",
             email: "newbie@example.com", invitation_token: "invite_token_abc")
    end
    let!(:mail) { described_class.invitation(invited_user, inviter) }

    it "正しい宛先に送信されること" do
      expect(mail.to).to eq(["newbie@example.com"])
    end

    it "正しい件名が設定されること" do
      expect(mail.subject).to eq("【ウケトリ】テスト株式会社への招待")
    end

    it "本文に招待されたユーザー名が含まれること" do
      expect(mail.body.encoded).to include("新人")
    end

    it "本文に招待者名が含まれること" do
      expect(mail.body.encoded).to include("管理者")
    end

    it "本文に招待受諾URLが含まれること" do
      expect(mail.body.encoded).to include("invitation/accept?token=invite_token_abc")
    end

    it "本文にテナント名が含まれること" do
      expect(mail.body.encoded).to include("テスト株式会社")
    end
  end
end
