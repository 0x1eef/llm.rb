# frozen_string_literal: true

require "setup"
require "llm/tools/exec"

RSpec.describe LLM::Tool::Exec do
  let(:tool) { described_class.new }

  describe ".function" do
    subject(:params) { described_class.function.params }

    it "defines the name param" do
      expect(params.properties[:name]).to be_a(LLM::Schema::String)
    end

    it "marks the name param as required" do
      expect(params.properties[:name]).to be_required
    end

    it "has a timeout parameter with a default" do
      expect(params.properties[:timeout].default).to eq(60)
    end
  end

  describe "#call" do
    it "raises when the command exceeds the timeout" do
      expect { tool.call(name: "sleep", arguments: ["10"], timeout: 0.1) }.to raise_error(
        RuntimeError,
        "command timed out after 0.1s"
      )
    end
  end
end
