# frozen_string_literal: true

require "setup"
require "llm/tools/exec"

RSpec.describe LLM::Tool::Exec do
  let(:tool) { described_class.new }
  let(:command) do
    instance_double(Test::Command, running?: false, success?: true, stdout: "hi\n", stderr: "")
  end

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

    context "when given arguments" do
      before do
        allow(command).to receive(:argv).and_return(command)
        allow(command).to receive(:spawn).and_return(command)
        allow(command).to receive(:limit).and_return(command)
        allow(LLM::Tool::Exec::Command).to receive(:new).and_return(command)
      end

      before { tool.call(name: "echo", arguments: ["hi"]) }

      it "limits stdout and stderr by max_chars" do
        expect(command).to have_received(:limit).with(
          stdout: LLM::Tool.max_chars,
          stderr: LLM::Tool.max_chars
        )
      end

      it "passes the arguments to the command" do
        expect(command).to have_received(:argv).with("hi")
      end

      it "returns the command output" do
        expect(tool.call(name: "echo", arguments: ["hi"])).to eq(
          ok: true, stdout: "hi\n", stderr: ""
        )
      end
    end
  end
end
