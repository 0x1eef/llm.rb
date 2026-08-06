# frozen_string_literal: true

require "setup"
require "llm/repl"

RSpec.describe LLM::Repl::Bar do
  describe "#to_s" do
    context "when given a used and total" do
      subject(:bar) { described_class.new(used: 500, total: 1000) }

      it "shows the remaining percentage" do
        expect(bar.to_s).to eq("│█████     │ 50.0%")
      end
    end

    context "when used is unknown" do
      subject(:bar) { described_class.new(used: nil, total: 1000) }

      it "renders an unknown bar" do
        expect(bar.to_s).to eq("│██████████│ ???")
      end
    end

    context "when total is unknown" do
      subject(:bar) { described_class.new(used: 100, total: 0) }

      it "renders an unknown bar" do
        expect(bar.to_s).to eq("│██████████│ ???")
      end
    end
  end
end
