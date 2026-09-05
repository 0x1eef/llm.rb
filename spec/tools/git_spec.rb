# frozen_string_literal: true

require "setup"
require "llm/tools/git"
require "llm/tools/shell"

RSpec.describe LLM::Tool::Git do
  let(:tool) { described_class.new }
  let(:shell) { instance_double(LLM::Tool::Shell) }
  let(:result) { {ok: true, stdout: "output", stderr: ""} }

  before do
    allow(LLM::Tool::Shell).to receive(:new).and_return(shell)
  end

  describe ".function" do
    let(:params) { described_class.function.params }

    it "defines the action param" do
      expect(params.properties[:action]).to be_a(LLM::Schema::String)
    end

    it "marks the action param as required" do
      expect(params.properties[:action]).to be_required
    end
  end

  describe "#call" do
    before do
      allow(shell).to receive(:call).and_return(result)
    end

    it "runs git through a shell tool" do
      tool.call(action: "status")
      expect(shell).to have_received(:call).with(name: "git", arguments: ["status"], timeout: 5)
    end

    it "returns the shell result" do
      expect(tool.call(action: "status")).to eq(result)
    end

    it "forwards the arguments" do
      tool.call(action: "log", arguments: ["--oneline"])
      expect(shell).to have_received(:call).with(name: "git", arguments: ["log", "--oneline"], timeout: 5)
    end

    it "forwards the timeout" do
      tool.call(action: "status", timeout: 10)
      expect(shell).to have_received(:call).with(name: "git", arguments: ["status"], timeout: 10)
    end
  end
end
