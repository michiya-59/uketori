# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Payments", type: :request do
  let!(:tenant) { create(:tenant) }
  let!(:owner) { create(:user, :owner, tenant: tenant) }
  let!(:accountant) { create(:user, :accountant, tenant: tenant) }
  let!(:member) { create(:user, :member, tenant: tenant) }
  let!(:customer) { create(:customer, tenant: tenant) }
  let!(:invoice) do
    create(:document, :invoice, tenant: tenant, customer: customer,
           created_by_user: owner, total_amount: 100_000, remaining_amount: 100_000)
  end

  describe "GET /api/v1/payments" do
    let!(:payment1) do
      PaymentRecord.create!(
        tenant: tenant, document: invoice, recorded_by_user: accountant,
        uuid: SecureRandom.uuid, amount: 30_000, payment_date: 2.days.ago.to_date,
        payment_method: "bank_transfer", matched_by: "manual"
      )
    end
    let!(:payment2) do
      PaymentRecord.create!(
        tenant: tenant, document: invoice, recorded_by_user: accountant,
        uuid: SecureRandom.uuid, amount: 20_000, payment_date: 1.day.ago.to_date,
        payment_method: "cash", matched_by: "manual"
      )
    end

    context "認証済みユーザーの場合" do
      it "入金一覧が返されること" do
        get "/api/v1/payments", headers: auth_headers(member)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["payments"].length).to eq(2)
        expect(body["meta"]["total_count"]).to eq(2)
      end
    end

    context "支払方法フィルタの場合" do
      it "指定した方法の入金のみ返されること" do
        get "/api/v1/payments",
            params: { filter: { payment_method: "cash" } },
            headers: auth_headers(member)

        body = response.parsed_body
        expect(body["payments"].length).to eq(1)
        expect(body["payments"][0]["payment_method"]).to eq("cash")
      end
    end

    context "帳票UUIDフィルタの場合" do
      it "指定帳票の入金のみ返されること" do
        get "/api/v1/payments",
            params: { filter: { document_uuid: invoice.uuid } },
            headers: auth_headers(member)

        body = response.parsed_body
        expect(body["payments"].length).to eq(2)
      end
    end

    context "日付フィルタの場合" do
      it "指定日付範囲の入金のみ返されること" do
        get "/api/v1/payments",
            params: { filter: { date_from: 1.day.ago.to_date.to_s, date_to: Date.current.to_s } },
            headers: auth_headers(member)

        body = response.parsed_body
        expect(body["payments"].length).to eq(1)
        expect(body["payments"][0]["amount"]).to eq(20_000)
      end
    end

    context "他テナントの入金の場合" do
      let!(:other_tenant) { create(:tenant, name: "他社") }
      let!(:other_user) { create(:user, :owner, tenant: other_tenant) }
      let!(:other_customer) { create(:customer, tenant: other_tenant) }
      let!(:other_invoice) do
        create(:document, :invoice, tenant: other_tenant, customer: other_customer,
               created_by_user: other_user, total_amount: 50_000, remaining_amount: 50_000)
      end
      let!(:other_payment) do
        PaymentRecord.create!(
          tenant: other_tenant, document: other_invoice, recorded_by_user: other_user,
          uuid: SecureRandom.uuid, amount: 50_000, payment_date: Date.current,
          payment_method: "bank_transfer", matched_by: "manual"
        )
      end

      it "他テナントの入金が含まれないこと" do
        get "/api/v1/payments", headers: auth_headers(member)

        body = response.parsed_body
        ids = body["payments"].map { |p| p["id"] }
        expect(ids).not_to include(other_payment.uuid)
      end
    end
  end

  describe "POST /api/v1/payments" do
    let!(:valid_params) do
      {
        document_uuid: invoice.uuid,
        payment: {
          amount: 50_000,
          payment_date: Date.current.to_s,
          payment_method: "bank_transfer",
          matched_by: "manual",
          memo: "テスト入金"
        }
      }
    end

    context "accountant以上のロールの場合" do
      it "入金が作成されること" do
        expect {
          post "/api/v1/payments", params: valid_params, headers: auth_headers(accountant), as: :json
        }.to change(PaymentRecord, :count).by(1)

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["payment"]["amount"]).to eq(50_000)
        expect(body["payment"]["document_uuid"]).to eq(invoice.uuid)
      end

      it "請求書のpayment_statusがpartialに更新されること" do
        post "/api/v1/payments", params: valid_params, headers: auth_headers(accountant), as: :json

        invoice.reload
        expect(invoice.payment_status).to eq("partial")
        expect(invoice.paid_amount).to eq(50_000)
        expect(invoice.remaining_amount).to eq(50_000)
      end

      it "全額入金でpayment_statusがpaidに更新されること" do
        params = valid_params.deep_dup
        params[:payment][:amount] = 100_000
        post "/api/v1/payments", params: params, headers: auth_headers(accountant), as: :json

        invoice.reload
        expect(invoice.payment_status).to eq("paid")
        expect(invoice.remaining_amount).to eq(0)
      end

      it "顧客のtotal_outstandingが更新されること" do
        post "/api/v1/payments", params: valid_params, headers: auth_headers(accountant), as: :json

        customer.reload
        expect(customer.total_outstanding).to eq(50_000)
      end
    end

    context "memberロールの場合" do
      it "403エラーが返されること" do
        post "/api/v1/payments", params: valid_params, headers: auth_headers(member), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "金額が0以下の場合" do
      it "422エラーが返されること" do
        params = valid_params.deep_dup
        params[:payment][:amount] = 0
        post "/api/v1/payments", params: params, headers: auth_headers(accountant), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "存在しない帳票UUIDの場合" do
      it "404エラーが返されること" do
        params = valid_params.deep_dup
        params[:document_uuid] = "non-existent-uuid"
        post "/api/v1/payments", params: params, headers: auth_headers(accountant), as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /api/v1/payments/:id" do
    let!(:payment) do
      PaymentRecord.create!(
        tenant: tenant, document: invoice, recorded_by_user: accountant,
        uuid: SecureRandom.uuid, amount: 100_000, payment_date: Date.current,
        payment_method: "bank_transfer", matched_by: "manual"
      )
    end

    context "admin以上のロールの場合" do
      it "入金が削除されること" do
        expect {
          delete "/api/v1/payments/#{payment.uuid}", headers: auth_headers(owner)
        }.to change(PaymentRecord, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end

      it "請求書のpayment_statusがunpaidに戻ること" do
        delete "/api/v1/payments/#{payment.uuid}", headers: auth_headers(owner)

        invoice.reload
        expect(invoice.payment_status).to eq("unpaid")
        expect(invoice.paid_amount).to eq(0)
      end

      it "顧客のtotal_outstandingが更新されること" do
        delete "/api/v1/payments/#{payment.uuid}", headers: auth_headers(owner)

        customer.reload
        expect(customer.total_outstanding).to eq(100_000)
      end
    end

    context "accountantロールの場合" do
      it "403エラーが返されること" do
        delete "/api/v1/payments/#{payment.uuid}", headers: auth_headers(accountant)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "memberロールの場合" do
      it "403エラーが返されること" do
        delete "/api/v1/payments/#{payment.uuid}", headers: auth_headers(member)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
