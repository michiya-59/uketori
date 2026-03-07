# frozen_string_literal: true

require "rails_helper"

RSpec.describe JwtService do
  let!(:tenant) { create(:tenant) }
  let!(:user) { create(:user, :owner, tenant: tenant) }

  describe ".encode" do
    context "有効なユーザーの場合" do
      it "アクセストークンとリフレッシュトークンを含むハッシュを返すこと" do
        result = described_class.encode(user)

        expect(result).to have_key(:access_token)
        expect(result).to have_key(:refresh_token)
        expect(result).to have_key(:expires_in)
        expect(result[:access_token]).to be_a(String)
        expect(result[:refresh_token]).to be_a(String)
      end
    end

    context "ユーザーがnilの場合" do
      it "ArgumentErrorが発生すること" do
        expect { described_class.encode(nil) }.to raise_error(ArgumentError)
      end
    end
  end

  describe ".decode" do
    let!(:tokens) { described_class.encode(user) }

    context "有効なアクセストークンの場合" do
      it "ペイロードを返すこと" do
        payload = described_class.decode(tokens[:access_token])

        expect(payload[:sub]).to eq(user.id)
        expect(payload[:tenant_id]).to eq(user.tenant_id)
        expect(payload[:type]).to eq("access")
        expect(payload[:jti]).to eq(user.jti)
      end
    end

    context "無効なトークンの場合" do
      it "JWT::DecodeErrorが発生すること" do
        expect { described_class.decode("invalid") }.to raise_error(JWT::DecodeError)
      end
    end
  end

  describe ".authenticate" do
    let!(:tokens) { described_class.encode(user) }

    context "有効なアクセストークンの場合" do
      it "ユーザーを返すこと" do
        result = described_class.authenticate(tokens[:access_token])
        expect(result).to eq(user)
      end
    end

    context "リフレッシュトークンを渡した場合" do
      it "nilを返すこと" do
        result = described_class.authenticate(tokens[:refresh_token])
        expect(result).to be_nil
      end
    end

    context "無効なトークンの場合" do
      it "nilを返すこと" do
        result = described_class.authenticate("invalid")
        expect(result).to be_nil
      end
    end

    context "jtiが変更された（サインアウト済み）場合" do
      it "nilを返すこと" do
        described_class.revoke(user)
        result = described_class.authenticate(tokens[:access_token])
        expect(result).to be_nil
      end
    end

    context "ユーザーが論理削除済みの場合" do
      it "nilを返すこと" do
        user.update!(deleted_at: Time.current)
        result = described_class.authenticate(tokens[:access_token])
        expect(result).to be_nil
      end
    end
  end

  describe ".refresh" do
    let!(:tokens) { described_class.encode(user) }

    context "有効なリフレッシュトークンの場合" do
      it "新しいトークンペアを返すこと" do
        result = described_class.refresh(tokens[:refresh_token])

        expect(result).to have_key(:access_token)
        expect(result).to have_key(:refresh_token)
        expect(result[:expires_in]).to eq(900)
      end
    end

    context "アクセストークンを渡した場合" do
      it "nilを返すこと" do
        result = described_class.refresh(tokens[:access_token])
        expect(result).to be_nil
      end
    end

    context "無効なトークンの場合" do
      it "nilを返すこと" do
        result = described_class.refresh("invalid")
        expect(result).to be_nil
      end
    end

    context "jtiが変更された（サインアウト済み）場合" do
      it "nilを返すこと" do
        described_class.revoke(user)
        result = described_class.refresh(tokens[:refresh_token])
        expect(result).to be_nil
      end
    end
  end

  describe ".revoke" do
    context "ユーザーのjtiをリセットする場合" do
      it "jtiが変更されること" do
        old_jti = user.jti
        described_class.revoke(user)
        expect(user.reload.jti).not_to eq(old_jti)
      end
    end
  end
end
