# frozen_string_literal: true

require "tmpdir"
require "setup"
require "llm/tools/read_file"

RSpec.describe LLM::Tool::ReadFile do
  let(:tool) { described_class.new }
  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, "sample.txt") }

  after { FileUtils.remove_entry(dir) }

  let(:content) do
    (1..20).map { |i| "line #{i}\n" }.join
  end

  before { File.write(path, content) }

  describe "#call" do
    context "when reading the entire file" do
      let(:result) { tool.call(path:) }

      it "returns the complete content" do
        expect(result[:content]).to eq(content)
      end
    end

    context "when given a start offset" do
      let(:result) { tool.call(path:, start: 5) }

      it "reads from the start line to the end" do
        expect(result[:content]).to eq((5..20).map { |i| "line #{i}\n" }.join)
      end
    end

    context "when given a start and stop offset" do
      let(:result) { tool.call(path:, start: 5, stop: 10) }

      it "reads the range between start and stop" do
        expect(result[:content]).to eq((5..10).map { |i| "line #{i}\n" }.join)
      end
    end

    context "when start is greater than stop" do
      let(:result) { tool.call(path:, start: 10, stop: 5) }

      it "swaps them and reads the range" do
        expect(result[:content]).to eq((5..10).map { |i| "line #{i}\n" }.join)
      end
    end
  end
end
