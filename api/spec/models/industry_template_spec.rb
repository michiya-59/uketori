# frozen_string_literal: true

require "rails_helper"

RSpec.describe IndustryTemplate, type: :model do
  describe "バリデーション" do
    let!(:template) { create(:industry_template) }

    context "有効な属性の場合" do
      it "バリデーションが通ること" do
        expect(template).to be_valid
      end
    end

    context "codeが空の場合" do
      it "バリデーションエラーになること" do
        template.code = nil
        expect(template).not_to be_valid
        expect(template.errors[:code]).to be_present
      end
    end

    context "codeが重複する場合" do
      it "バリデーションエラーになること" do
        duplicate = build(:industry_template, code: template.code)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:code]).to be_present
      end
    end

    context "nameが空の場合" do
      it "バリデーションエラーになること" do
        template.name = nil
        expect(template).not_to be_valid
        expect(template.errors[:name]).to be_present
      end
    end
  end

  describe ".active" do
    let!(:active_template) { create(:industry_template, code: "active_test", is_active: true) }
    let!(:inactive_template) { create(:industry_template, :inactive, code: "inactive_test") }

    it "有効なテンプレートのみ返すこと" do
      results = described_class.active
      expect(results).to include(active_template)
      expect(results).not_to include(inactive_template)
    end
  end

  describe ".ordered" do
    let!(:template_c) { create(:industry_template, code: "c_test", sort_order: 3) }
    let!(:template_a) { create(:industry_template, code: "a_test", sort_order: 1) }
    let!(:template_b) { create(:industry_template, code: "b_test", sort_order: 2) }

    it "sort_order昇順でソートされること" do
      results = described_class.ordered
      codes = results.map(&:code)
      expect(codes.index("a_test")).to be < codes.index("b_test")
      expect(codes.index("b_test")).to be < codes.index("c_test")
    end
  end
end
