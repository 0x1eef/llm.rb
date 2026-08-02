# frozen_string_literal: true

require "setup"
require "llm/repl"

RSpec.describe LLM::Repl::Markdown do
  describe "typographic symbols" do
    it "renders an ellipsis for '...'" do
      expect(rendered("...")).to eq("…")
    end

    it "renders en and em dashes" do
      expect(rendered("a -- b --- c")).to eq("a – b — c")
    end

    it "renders smart quotes" do
      expect(rendered("'hi' \"hi\"")).to eq("‘hi’ “hi”")
    end

    it "keeps surrounding text intact" do
      expect(rendered("some words ... more")).to eq("some words … more")
    end
  end

  ##
  # Returns the concatenated text of the rendered AST.
  # @param [String] text
  # @return [String]
  def rendered(text)
    described_class.new(text, 80).ast.map { _1[:text] }.join
  end
end
