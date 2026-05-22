# frozen_string_literal: true

require "setup"

RSpec.describe LLM::MCP do
  let(:transport) do
    Class.new do
      attr_reader :writes

      def initialize(messages)
        @messages = messages.dup
        @writes = []
      end

      def running?
        true
      end

      def write(message)
        @writes << message
      end

      def read_nonblock
        raise IO::EAGAINWaitReadable if @messages.empty?
        @messages.shift
      end
    end.new(messages)
  end

  let(:mcp) do
    described_class.allocate.tap do |instance|
      instance.instance_variable_set(:@transport, transport)
      instance.instance_variable_set(:@timeout, 0.1)
    end
  end

  describe "#prompts" do
    let(:messages) do
      [
        {
          "jsonrpc" => "2.0",
          "id" => 0,
          "result" => {
            "prompts" => [
              {"name" => "hello_world", "description" => "Prompt description"}
            ]
          }
        }
      ]
    end

    it "calls prompts/list and wraps the result" do
      prompts = mcp.prompts
      expect(transport.writes.last).to include(
        method: "prompts/list",
        params: {},
        id: 0
      )
      expect(prompts.first.name).to eq("hello_world")
      expect(prompts.first.description).to eq("Prompt description")
    end
  end

  describe "#find_prompt" do
    let(:messages) do
      [
        {
          "jsonrpc" => "2.0",
          "id" => 0,
          "result" => {
            "description" => "Prompt description",
            "messages" => [
              {
                "role" => "user",
                "content" => {"type" => "text", "text" => "Hello"}
              }
            ]
          }
        }
      ]
    end

    it "calls prompts/get and wraps the result" do
      prompt = mcp.find_prompt(name: "hello_world", arguments: {"name" => "world"})
      expect(transport.writes.last).to include(
        method: "prompts/get",
        params: {name: "hello_world", arguments: {"name" => "world"}},
        id: 0
      )
      expect(prompt.description).to eq("Prompt description")
      expect(prompt.messages.first).to be_a(LLM::Message)
      expect(prompt.messages.first.role).to eq("user")
      expect(prompt.messages.first.content).to eq("Hello")
      expect(prompt.messages.first.extra.original_content.type).to eq("text")
      expect(prompt.messages.first.extra.original_content.text).to eq("Hello")
    end
  end

  describe "#run" do
    let(:messages) { [] }

    before do
      allow(transport).to receive(:start)
      allow(transport).to receive(:stop)
      allow(mcp).to receive(:call)
    end

    it "starts and stops around a block" do
      result = mcp.run { mcp }
      expect(transport).to have_received(:start).ordered
      expect(transport).to have_received(:stop).ordered
      expect(result).to eq(mcp)
    end

    it "stops when the block raises" do
      expect do
        mcp.run { raise "boom" }
      end.to raise_error("boom")
      expect(transport).to have_received(:start).ordered
      expect(transport).to have_received(:stop).ordered
    end

    it "requires a block" do
      expect do
        mcp.run
      end.to raise_error(LocalJumpError)
      expect(transport).to have_received(:start).ordered
      expect(transport).to have_received(:stop).ordered
    end
  end

  describe "#session" do
    let(:messages) { [] }
    subject(:result) { mcp.session { mcp } }

    before do
      allow(transport).to receive(:start)
      allow(transport).to receive(:stop)
      allow(mcp).to receive(:call)
    end

    it "starts the transport" do
      result
      expect(transport).to have_received(:start).ordered
    end

    it "stops the transport" do
      result
      expect(transport).to have_received(:stop).ordered
    end

    it "returns the block result" do
      expect(result).to eq(mcp)
    end
  end

  describe "outside #run" do
    let(:transport) do
      Class.new do
        attr_accessor :running

        def initialize
          @running = false
        end

        def running?
          @running
        end
      end.new
    end

    let(:mcp) do
      described_class.allocate.tap do |instance|
        instance.instance_variable_set(:@transport, transport)
        instance.instance_variable_set(:@timeout, 0.1)
      end
    end

    before do
      allow(mcp).to receive(:start) { transport.running = true }
      allow(mcp).to receive(:stop) { transport.running = false }
    end

    describe "#tools" do
      subject(:tools) { mcp.tools }

      before do
        allow(mcp).to receive(:call).with(transport, "tools/list").and_return(
          "tools" => [
            {"name" => "list_directory", "description" => "list a directory", "inputSchema" => {type: "object", properties: {}}}
          ]
        )
      end

      context "when the transport is stopped" do
        it "starts the transport" do
          tools
          expect(mcp).to have_received(:start).ordered
        end

        it "stops the transport" do
          tools
          expect(mcp).to have_received(:stop).ordered
        end

        it "returns the discovered tools" do
          expect(tools[0].name).to eq("list_directory")
        end
      end

      context "when the transport is already running" do
        before do
          transport.running = true
        end

        it "does not start the transport again" do
          tools
          expect(mcp).to_not have_received(:start)
        end

        it "does not stop the transport" do
          tools
          expect(mcp).to_not have_received(:stop)
        end
      end
    end

    describe "#call_tool" do
      subject(:result) { mcp.call_tool("hello", {"name" => "world"}) }

      before do
        allow(mcp).to receive(:call).with(transport, "tools/call", {name: "hello", arguments: {"name" => "world"}})
          .and_return("structuredContent" => {"message" => "hello world"})
      end

      context "when the transport is stopped" do
        it "starts the transport" do
          result
          expect(mcp).to have_received(:start).ordered
        end

        it "stops the transport" do
          result
          expect(mcp).to have_received(:stop).ordered
        end

        it "returns the tool result" do
          expect(result).to eq("message" => "hello world")
        end
      end

      context "when the transport is already running" do
        before do
          transport.running = true
        end

        it "does not start the transport again" do
          result
          expect(mcp).to_not have_received(:start)
        end

        it "does not stop the transport" do
          result
          expect(mcp).to_not have_received(:stop)
        end
      end
    end
  end
end
