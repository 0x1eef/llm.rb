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

      def write(message)
        @writes << message
      end

      def read_nonblock
        raise IO::WaitReadable.new if @messages.empty?
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
      expect(prompt.messages.first.role).to eq("user")
      expect(prompt.messages.first.content.text).to eq("Hello")
    end
  end
end
