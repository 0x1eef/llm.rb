# frozen_string_literal: true

require "setup"

RSpec.describe LLM::Stream do
  let(:stream) { described_class.new }

  let(:tool_class) do
    Class.new(LLM::Tool) do
      name "system"

      def call(command:)
        {"ok" => command == "date"}
      end
    end
  end

  let(:tool) do
    tool_class.function.dup.tap do |fn|
      fn.id = "call_1"
      fn.arguments = {"command" => "date"}
    end
  end

  describe "#on_content" do
    it "returns nil" do
      expect(stream.on_content("hello")).to be_nil
    end
  end

  describe "#<<" do
    it "aliases #on_content" do
      expect(stream << "hello").to be_nil
    end
  end

  describe "#on_reasoning_content" do
    it "returns nil" do
      expect(stream.on_reasoning_content("think")).to be_nil
    end
  end

  describe "#on_tool_call" do
    it "returns nil" do
      expect(stream.on_tool_call(tool, nil)).to be_nil
    end
  end

  describe "#on_tool_return" do
    it "returns nil" do
      expect(stream.on_tool_return(tool, stream.tool_not_found(tool))).to be_nil
    end
  end

  describe "#tool_not_found" do
    it "returns an in-band error" do
      expect(stream.tool_not_found(tool).to_h).to eq(
        id: "call_1", name: "system",
        value: {error: true, type: "LLM::NoSuchToolError", message: "tool not found"}
      )
    end

    it "marks the return as an error" do
      expect(stream.tool_not_found(tool)).to be_error
    end
  end

  describe LLM::Function::Return, "#error?" do
    it "returns true for automatic error returns" do
      ret = LLM::Stream.new.tool_not_found(tool)
      expect(ret.error?).to be(true)
    end

    it "returns false for successful returns" do
      ret = LLM::Function::Return.new("call_1", "system", {"ok" => true})
      expect(ret.error?).to be(false)
    end
  end

  describe "#queue" do
    subject(:queue) { stream.queue }

    it "returns a lazy queue" do
      expect(queue).to be_a(LLM::Stream::Queue)
      expect(queue).to equal(stream.queue)
    end
  end

  describe "#wait" do
    before do
      stream.queue << stream.tool_not_found(tool)
    end

    it "forwards to the queue" do
      expect(stream.wait(:thread).map(&:to_h)).to eq(
        [{id: "call_1", name: "system", value: {error: true, type: "LLM::NoSuchToolError", message: "tool not found"}}]
      )
    end
  end

  context "when a subclass overrides callbacks" do
    let(:stream) do
      Class.new(described_class) do
        attr_reader :content, :reasoning_content, :calls, :returns

        def initialize
          @content = +""
          @reasoning_content = +""
          @calls = []
          @returns = []
        end

        def on_content(value)
          @content << value
        end

        def on_reasoning_content(value)
          @reasoning_content << value
        end

        def on_tool_call(fn, error)
          @calls << [fn, error]
        end

        def on_tool_return(fn, ret)
          @returns << [fn, ret]
        end
      end.new
    end

    it "handles streamed content" do
      stream.on_content("hello")
      expect(stream.content).to eq("hello")
    end

    it "handles reasoning content" do
      stream.on_reasoning_content("think")
      expect(stream.reasoning_content).to eq("think")
    end

    it "handles tool calls" do
      stream.on_tool_call(tool, nil)
      expect(stream.calls).to eq([[tool, nil]])
    end

    it "handles finished tools" do
      ret = stream.tool_not_found(tool)
      stream.on_tool_return(tool, ret)
      expect(stream.returns).to eq([[tool, ret]])
    end
  end

  context "when using the queue" do
    describe "#wait" do
      context "when given queued function returns" do
        before do
          stream.queue << stream.tool_not_found(tool)
        end

        it "returns the queued values" do
          expect(stream.wait(:thread).map(&:to_h)).to eq(
            [{id: "call_1", name: "system", value: {error: true, type: "LLM::NoSuchToolError", message: "tool not found"}}]
          )
        end
      end

      context "when given spawned work" do
        before do
          stream.queue << tool.spawn(:thread)
        end

        it "waits for the spawned work" do
          expect(stream.wait(:thread).map(&:to_h)).to eq(
            [{id: "call_1", name: "system", value: {"ok" => true}}]
          )
        end

        it "emits on_tool_return" do
          events = []
          stream = Class.new(described_class) do
            define_method(:on_tool_return) { |fn, ret| events << [fn, ret] }
          end.new
          stream.queue << tool.spawn(:thread)

          returns = stream.wait(:thread)

          expect(events).to eq([[tool, returns.fetch(0)]])
        end
      end
    end
  end
end
