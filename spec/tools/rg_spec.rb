# frozen_string_literal: true

require "setup"
require "llm/tools/rg"

RSpec.describe LLM::Tool::Rg do
  let(:tool) { described_class.new }
  let(:command) do
    instance_double(Test::Command, running?: false, success?: true, stdout: "match\n", stderr: "")
  end

  before do
    allow(command).to receive(:argv).and_return(command)
    allow(command).to receive(:spawn).and_return(command)
    allow(described_class::Command).to receive(:new).and_return(command)
  end

  describe ".function" do
    let(:params) { described_class.function.params }

    it "defines the patterns param" do
      expect(params.properties[:patterns]).to be_a(LLM::Schema::Array)
    end

    it "marks the patterns param as required" do
      expect(params.properties[:patterns]).to be_required
    end
  end

  describe "#call" do
    subject(:call) { tool.call(patterns: %w[foo bar]) }

    it "passes a -e switch per pattern" do
      call
      expect(command).to have_received(:argv).with("-e", "foo", "-e", "bar", Dir.getwd)
    end

    it "limits the match count per file" do
      call
      expect(command).to have_received(:argv).with("-m", 10)
    end
  end

  describe "#call with a custom max_count" do
    subject(:call) { tool.call(patterns: %w[foo], max_count: 5) }

    it "passes the max count to rg" do
      call
      expect(command).to have_received(:argv).with("-m", 5)
    end
  end

  describe "#call with a non-integer max_count" do
    it "raises an error" do
      expect {
        tool.call(patterns: %w[foo], max_count: "x")
      }.to raise_error("max_count must be a positive integer")
    end
  end

  describe "#call when path is the root" do
    it "raises an error" do
      expect {
        tool.call(patterns: %w[foo], path: "/")
      }.to raise_error("you can't search from the root of the filesystem")
    end
  end

  describe "#call when patterns is [\".\"]" do
    it "raises an error" do
      expect {
        tool.call(patterns: ["."])
      }.to raise_error("narrow your search")
    end
  end
end
