# frozen_string_literal: true

require "setup"
require "llm/tools/rg"

RSpec.describe LLM::Tool::Rg do
  let(:tool) { described_class.new }
  let(:command) do
    instance_double(Test::Cmd, success?: true, stdout: "match\n", stderr: "")
  end

  describe ".function" do
    subject(:params) { described_class.function.params }

    it "defines the patterns param" do
      expect(params.properties[:patterns]).to be_a(LLM::Schema::Array)
    end

    it "marks the patterns param as required" do
      expect(params.properties[:patterns]).to be_required
    end
  end

  describe "#call" do
    subject(:call) { tool.call(patterns: %w[foo bar]) }

    before do
      expect(described_class::Command).to receive(:new).with("rg").and_return(command)
      expect(command).to receive(:argv).with("-e", "foo", "-e", "bar", Dir.getwd).and_return(command)
      expect(command).to receive(:spawn).and_return(command)
    end

    it "spawns rg with one -e switch per pattern" do
      expect(call).to eq(
        ok: true,
        stdout: "match\n",
        stderr: ""
      )
    end
  end
end
