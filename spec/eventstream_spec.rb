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

    context "when given reasoning content" do
      let(:stream) do
        Class.new do
          attr_reader :content, :reasoning_content

          def initialize
            @content = +""
            @reasoning_content = +""
          end

          def on_content(value)
            @content << value
          end

          def on_reasoning_content(value)
            @reasoning_content << value
          end
        end.new
      end

      before do
        parser << %(data: {"choices":[{"index":0,"delta":{"reasoning_content":"Think"}}]}\n)
        parser << %(data: {"choices":[{"index":0,"delta":{"content":"Answer"}}]}\n)
      end

      it "emits assistant content through on_content" do
        expect(stream.content).to eq("Answer")
      end

      it "emits reasoning content through on_reasoning_content" do
        expect(stream.reasoning_content).to eq("Think")
      end

      it "preserves streamed reasoning content in the parsed body" do
        expect(handler.body.dig("choices", 0, "message", "reasoning_content")).to eq("Think")
      end
    end
  end
end
