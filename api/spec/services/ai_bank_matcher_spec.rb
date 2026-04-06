# frozen_string_literal: true

require "rails_helper"

RSpec.describe AiBankMatcher do
  let!(:tenant) { create(:tenant) }
  let!(:user) { create(:user, :owner, tenant: tenant) }
  let!(:customer) { create(:customer, tenant: tenant, company_name: "株式会社テスト商事", company_name_kana: "テストショウジ") }
  let!(:invoice) do
    create(:document, :invoice, tenant: tenant, customer: customer, created_by_user: user,
           total_amount: 100_000, remaining_amount: 100_000, payment_status: "unpaid")
  end
  let!(:batch_id) { SecureRandom.uuid }

  describe ".call" do
    context "金額完全一致 + 名前一致の場合" do
      let!(:statement) do
        create(:bank_statement, tenant: tenant, amount: 100_000,
               payer_name: "カ）テストショウジ", import_batch_id: batch_id)
      end

      it "auto_matchedとしてマッチングされること" do
        results = described_class.call(tenant, batch_id, user: user)

        expect(results[:auto_matched]).to eq(1)
        expect(results[:needs_review]).to eq(0)
        expect(results[:unmatched]).to eq(0)
      end

      it "入金レコードが作成されること" do
        expect {
          described_class.call(tenant, batch_id, user: user)
        }.to change(PaymentRecord, :count).by(1)

        payment = PaymentRecord.last
        expect(payment.amount).to eq(100_000)
        expect(payment.matched_by).to eq("ai_auto")
        expect(payment.bank_statement_id).to eq(statement.id)
      end

      it "銀行明細がマッチ済みに更新されること" do
        described_class.call(tenant, batch_id, user: user)

        statement.reload
        expect(statement.is_matched).to be true
        expect(statement.matched_document_id).to eq(invoice.id)
      end

      it "請求書のpayment_statusがpaidに更新されること" do
        described_class.call(tenant, batch_id, user: user)

        invoice.reload
        expect(invoice.payment_status).to eq("paid")
      end
    end

    context "金額一致 + 名前不一致の場合" do
      let!(:statement) do
        create(:bank_statement, tenant: tenant, amount: 100_000,
               payer_name: "ヤマダタロウ", import_batch_id: batch_id)
      end

      it "未マッチになること" do
        results = described_class.call(tenant, batch_id, user: user)

        expect(results[:auto_matched]).to eq(0)
        expect(results[:needs_review]).to eq(0)
        expect(results[:unmatched]).to eq(1)
      end
    end

    context "金額不一致の場合" do
      let!(:statement) do
        create(:bank_statement, tenant: tenant, amount: 200_000,
               payer_name: "カ）テストショウジ", import_batch_id: batch_id)
      end

      it "自動マッチングされないこと" do
        results = described_class.call(tenant, batch_id, user: user)

        expect(results[:auto_matched]).to eq(0)
      end
    end

    context "複数明細がある場合" do
      let!(:customer2) { create(:customer, tenant: tenant, company_name: "サンプル工業", company_name_kana: "サンプルコウギョウ") }
      let!(:invoice2) do
        create(:document, :invoice, tenant: tenant, customer: customer2, created_by_user: user,
               total_amount: 50_000, remaining_amount: 50_000, payment_status: "unpaid")
      end
      let!(:stmt1) do
        create(:bank_statement, tenant: tenant, amount: 100_000,
               payer_name: "カ）テストショウジ", import_batch_id: batch_id)
      end
      let!(:stmt2) do
        create(:bank_statement, tenant: tenant, amount: 50_000,
               payer_name: "サンプルコウギョウ", import_batch_id: batch_id)
      end

      it "複数の明細がマッチングされること" do
        results = described_class.call(tenant, batch_id, user: user)

        expect(results[:auto_matched]).to eq(2)
        expect(PaymentRecord.count).to eq(2)
      end
    end

    context "銀行振込名が後方の法人格略称付きの場合" do
      let!(:customer) do
        create(:customer, tenant: tenant,
                          company_name: "合同会社ライズ",
                          company_name_kana: "ゴウドウガイシャ ライズ")
      end
      let!(:rise_invoice) do
        create(:document, :invoice, :approved, tenant: tenant, customer: customer, created_by_user: user,
               document_number: "INV-202604-0005",
               issue_date: Date.new(2026, 4, 6),
               total_amount: 80_000, remaining_amount: 80_000, payment_status: "unpaid")
      end
      let!(:statement) do
        create(:bank_statement, tenant: tenant,
               transaction_date: Date.new(2026, 4, 6),
               amount: 80_000,
               payer_name: "ライズ（ド",
               description: "振込１",
               import_batch_id: batch_id)
      end

      before do
        invoice.destroy!
      end

      it "法人格略称を除去して自動マッチすること" do
        results = described_class.call(tenant, batch_id, user: user)

        expect(results[:auto_matched]).to eq(1)
        expect(results[:needs_review]).to eq(0)
        expect(results[:unmatched]).to eq(0)
        expect(statement.reload.matched_document_id).to eq(rise_invoice.id)
      end
    end

    context "英語社名由来のカナ揺れがあり同額請求書が複数ある場合" do
      let!(:customer) do
        create(:customer, tenant: tenant,
                          company_name: "株式会社Day One Partners",
                          company_name_kana: "カブシキカイシャワンデイパートナーズ")
      end
      let!(:march_invoice) do
        create(:document, :invoice, :approved, tenant: tenant, customer: customer, created_by_user: user,
               document_number: "INV-202603-0001",
               issue_date: Date.new(2026, 3, 1), due_date: Date.new(2026, 3, 30),
               total_amount: 5500, remaining_amount: 5500, payment_status: "unpaid")
      end
      let!(:older_invoice) do
        create(:document, :invoice, :approved, tenant: tenant, customer: customer, created_by_user: user,
               document_number: "INV-202602-0001",
               issue_date: Date.new(2026, 2, 1), due_date: Date.new(2026, 2, 28),
               total_amount: 5500, remaining_amount: 5500, payment_status: "unpaid")
      end
      let!(:statement) do
        create(:bank_statement, tenant: tenant,
               transaction_date: Date.new(2026, 3, 31),
               amount: 5500,
               payer_name: "カ）デイワンパ−トナ−ズ",
               description: "カ）デイワンパ−トナ−ズ",
               import_batch_id: batch_id)
      end

      before do
        invoice.destroy!
      end

      it "自動マッチしないこと" do
        results = described_class.call(tenant, batch_id, user: user)

        expect(results[:auto_matched]).to eq(0)
        expect(results[:needs_review]).to eq(0)
        expect(results[:unmatched]).to eq(1)
        expect(statement.reload.matched_document_id).to be_nil
      end
    end

    context "既にマッチ済みの明細がある場合" do
      let!(:matched_stmt) do
        create(:bank_statement, :matched, tenant: tenant, amount: 100_000,
               import_batch_id: batch_id)
      end

      it "マッチ済み明細がスキップされること" do
        results = described_class.call(tenant, batch_id, user: user)

        expect(results[:auto_matched]).to eq(0)
        expect(results[:needs_review]).to eq(0)
        expect(results[:unmatched]).to eq(0)
      end
    end
  end

  describe ".suggest" do
    let!(:statement) do
      create(:bank_statement, tenant: tenant, amount: 100_000,
             payer_name: "カ）テストショウジ")
    end

    context "マッチ候補がある場合" do
      it "提案結果を返すこと" do
        result = described_class.suggest(tenant, statement)

        expect(result).to be_present
        expect(result[:document]).to eq(invoice)
        expect(result[:confidence]).to be > 0.5
      end
    end
  end
end
