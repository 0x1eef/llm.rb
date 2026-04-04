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

  context "when given the default implementation" do
    it "returns nil from callbacks" do
      expect(stream.on_content("hello")).to be_nil
      expect(stream << "hello").to be_nil
      expect(stream.on_reasoning_content("think")).to be_nil
      expect(stream.on_tool_call(tool, nil)).to be_nil
    end

    it "returns an in-band error for unknown tools" do
      expect(stream.tool_not_found(tool).to_h).to eq(
        id: "call_1", name: "system",
        value: {error: true, type: "LLM::NoSuchToolError", message: "tool not found"}
      )
    end

    context "#queue" do
      subject(:queue) { stream.queue }

      it "returns a lazy queue" do
        expect(queue).to be_a(LLM::Stream::Queue)
        expect(queue).to equal(stream.queue)
      end
    end
  end

  context "when a subclass overrides callbacks" do
    let(:stream) do
      Class.new(described_class) do
        attr_reader :content, :reasoning_content, :tools

        def initialize
          @content = +""
          @reasoning_content = +""
          @tools = []
        end

        def on_content(value)
          @content << value
        end

        def on_reasoning_content(value)
          @reasoning_content << value
        end

        def on_tool_call(fn, error)
          @tools << [fn, error]
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
      expect(stream.tools).to eq([[tool, nil]])
    end
  end

  context "when using the queue" do
    it "returns queued function returns" do
      stream.queue << stream.tool_not_found(tool)
      expect(stream.queue.wait(:thread).map(&:to_h)).to eq(
        [{id: "call_1", name: "system", value: {error: true, type: "LLM::NoSuchToolError", message: "tool not found"}}]
      )
    end

    it "waits for spawned work" do
      stream.queue << tool.spawn(:thread)
      expect(stream.queue.wait(:thread).map(&:to_h)).to eq(
        [{id: "call_1", name: "system", value: {"ok" => true}}]
      )
    end
  end
end
