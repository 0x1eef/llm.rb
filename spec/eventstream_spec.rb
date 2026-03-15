# frozen_string_literal: true

require "setup"
require "stringio"

RSpec.describe LLM::EventStream::Parser do
  let(:provider) { LLM.openai(key: "test") }
  let(:stream) { StringIO.new }
  let(:handler) { LLM::EventHandler.new(provider.class::StreamParser.new(stream)) }
  subject(:parser) do
    described_class.new.tap do |instance|
      instance.register(handler)
    end
  end

  after { parser.free }

  describe "#<<" do
    let(:partial_line) { 'data: {"choices":[{"index":0,"delta":{"content":"He' }
    let(:remaining_lines) do
      <<~DATA
        y"}}]}
        data: {"choices":[{"index":0,"delta":{"content":" there"}}]}
      DATA
    end

    context "when given a partial sse data line without a trailing newline" do
      before { parser << partial_line }

      it "does not emit content to the stream" do
        expect(stream.string).to eq("")
      end

      it "does not build a response body yet" do
        expect(handler.body).to eq({})
      end
    end

    context "when the newline and remaining data arrive later" do
      before do
        parser << partial_line
        parser << remaining_lines
      end

      it "preserves the full streamed content" do
        expect(stream.string).to eq("Hey there")
      end

      it "preserves the full parsed message content" do
        expect(handler.body.dig("choices", 0, "message", "content")).to eq("Hey there")
      end
    end
  end
end
