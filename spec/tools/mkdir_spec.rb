# frozen_string_literal: true

require "setup"
require "llm/tools/mkdir"
require "llm/tools/shell"

RSpec.describe LLM::Tool::Mkdir do
  let(:tool) { described_class.new }
  let(:shell) { instance_double(LLM::Tool::Shell) }
  let(:result) { {ok: true, stdout: "", stderr: ""} }

  before do
    allow(LLM::Tool::Shell).to receive(:new).and_return(shell)
  end

  describe ".function" do
    let(:params) { described_class.function.params }

    it "defines the path param" do
      expect(params.properties[:path]).to be_a(LLM::Schema::String)
    end

    it "marks the path param as required" do
      expect(params.properties[:path]).to be_required
    end
  end

  describe "#call" do
    before do
      allow(shell).to receive(:call).and_return(result)
    end

    it "runs mkdir through a shell tool" do
      tool.call(path: "/tmp/new-dir")
      expect(shell).to have_received(:call).with(
        name: "mkdir",
        arguments: ["-p", "/tmp/new-dir"],
        max_chars: LLM::Tool.max_chars
      )
    end

    it "returns the shell result" do
      expect(tool.call(path: "/tmp/new-dir")).to eq(result)
    end
  end
end
