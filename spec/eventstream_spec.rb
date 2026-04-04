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
        Class.new(LLM::Stream) do
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

    context "when given a streamed tool call" do
      let(:system) do
        Class.new(LLM::Tool) do
          name "system"
          description "run shell commands"
        end
      end

      let(:stream) do
        Class.new(LLM::Stream) do
          attr_reader :calls

          def initialize
            @calls = []
          end

          def on_tool_call(fn, error)
            @calls << [fn, error]
          end
        end.new
      end

      before { LLM::Tool.clear_registry! }
      before { system }

      before do
        parser << %(data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_1","type":"function","function":{"name":"system","arguments":"{\\"command\\":\\"date\\"}"}}]}}]}\n)
      end

      context "when given the emitted function" do
        subject(:call) { stream.calls.fetch(0) }
        subject(:fn) { call.fetch(0) }

        it "emits a function through on_tool_call" do
          expect(fn).to be_a(LLM::Function)
        end

        it "does not emit an error for a resolved tool" do
          expect(call.fetch(1)).to be_nil
        end

        it "preserves the function id" do
          expect(fn.id).to eq("call_1")
        end

        it "preserves the function name" do
          expect(fn.name).to eq("system")
        end

        it "preserves parsed arguments" do
          expect(fn.arguments).to eq({"command" => "date"})
        end
      end
    end

    context "when given an unresolved streamed tool call" do
      let(:stream) do
        Class.new(LLM::Stream) do
          attr_reader :calls

          def initialize
            @calls = []
          end

          def on_tool_call(fn, error)
            @calls << [fn, error]
          end
        end.new
      end

      before { LLM::Tool.clear_registry! }

      before do
        parser << %(data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_2","type":"function","function":{"name":"missing","arguments":"{\\"command\\":\\"date\\"}"}}]}}]}\n)
      end

      it "emits the tool metadata and an in-band error" do
        fn, error = stream.calls.fetch(0)
        expect(fn.id).to eq("call_2")
        expect(fn.name).to eq("missing")
        expect(fn.arguments).to eq({"command" => "date"})
        expect(error.to_h).to eq(
          id: "call_2", name: "missing",
          value: {error: true, type: "LLM::NoSuchToolError", message: "tool not found"}
        )
      end
    end
  end
end
