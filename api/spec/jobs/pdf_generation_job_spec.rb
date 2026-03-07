# frozen_string_literal: true

require "rails_helper"

RSpec.describe PdfGenerationJob do
  let!(:tenant) { create(:tenant) }
  let!(:user) { create(:user, :owner, tenant: tenant) }
  let!(:customer) { create(:customer, tenant: tenant) }
  let!(:document) do
    create(:document, tenant: tenant, customer: customer, created_by_user: user,
           document_type: "estimate")
  end

  describe "#perform" do
    it "PdfGeneratorを呼び出すこと" do
      expect(PdfGenerator).to receive(:call).with(document)

      described_class.new.perform(document.id)
    end

    it "ジョブがキューに投入できること" do
      expect {
        described_class.perform_later(document.id)
      }.to have_enqueued_job(described_class).with(document.id)
    end
  end
end
