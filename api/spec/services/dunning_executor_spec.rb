# frozen_string_literal: true

require "rails_helper"

RSpec.describe DunningExecutor do
  let!(:tenant) { create(:tenant) }
  let!(:user) { create(:user, :owner, tenant: tenant) }
  let!(:customer) { create(:customer, tenant: tenant, email: "billing@example.com") }

  describe ".call" do
    context "期限超過の請求書がある場合" do
      let!(:rule) do
        create(:dunning_rule, tenant: tenant, trigger_days_after_due: 7,
               max_dunning_count: 3, interval_days: 7)
      end
      let!(:overdue_invoice) do
        create(:document, :invoice, tenant: tenant, customer: customer, created_by_user: user,
               total_amount: 100_000, remaining_amount: 100_000,
               payment_status: "overdue", due_date: 10.days.ago.to_date)
      end

      it "督促メールが送信されること" do
        result = described_class.call(tenant)

        expect(result[:sent]).to eq(1)
        expect(DunningLog.count).to eq(1)
      end

      it "テンプレート変数が展開されること" do
        described_class.call(tenant)

        log = DunningLog.last
        expect(log.email_body).to include(customer.company_name)
        expect(log.overdue_days).to eq(10)
      end

      it "帳票の督促情報が更新されること" do
        described_class.call(tenant)

        overdue_invoice.reload
        expect(overdue_invoice.dunning_count).to eq(1)
        expect(overdue_invoice.last_dunning_at).to be_present
      end
    end

    context "max_dunning_countに達している場合" do
      let!(:rule) do
        create(:dunning_rule, tenant: tenant, trigger_days_after_due: 7,
               max_dunning_count: 1, interval_days: 1)
      end
      let!(:overdue_invoice) do
        create(:document, :invoice, tenant: tenant, customer: customer, created_by_user: user,
               total_amount: 100_000, remaining_amount: 100_000,
               payment_status: "overdue", due_date: 10.days.ago.to_date)
      end
      let!(:existing_log) do
        create(:dunning_log, tenant: tenant, document: overdue_invoice,
               dunning_rule: rule, customer: customer)
      end

      it "督促がスキップされること" do
        result = described_class.call(tenant)

        expect(result[:skipped]).to eq(1)
        expect(result[:sent]).to eq(0)
      end
    end

    context "督促ルールがない場合" do
      it "何も実行されないこと" do
        result = described_class.call(tenant)

        expect(result).to eq({ sent: 0, skipped: 0, failed: 0 })
      end
    end

    context "期限超過日数がルールに満たない場合" do
      let!(:rule) do
        create(:dunning_rule, tenant: tenant, trigger_days_after_due: 30)
      end
      let!(:slightly_overdue) do
        create(:document, :invoice, tenant: tenant, customer: customer, created_by_user: user,
               total_amount: 50_000, remaining_amount: 50_000,
               payment_status: "overdue", due_date: 5.days.ago.to_date)
      end

      it "督促がスキップされること" do
        result = described_class.call(tenant)

        expect(result[:skipped]).to eq(1)
      end
    end
  end
end
