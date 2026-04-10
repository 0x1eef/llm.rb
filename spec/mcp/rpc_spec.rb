# frozen_string_literal: true

require "setup"

RSpec.describe LLM::MCP::RPC do
  let(:client) do
    Class.new do
      include LLM::MCP::RPC

      def initialize(timeout: 0.1)
        @timeout = timeout
      end
    end.new
  end

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

  describe "#call" do
    let(:messages) { [] }

    it "ignores notifications while waiting for the response" do
      messages.concat([
        {"jsonrpc" => "2.0", "method" => "notifications/message", "params" => {"level" => "info"}},
        {"jsonrpc" => "2.0", "id" => 0, "result" => {"ok" => true}}
      ])
      expect(client.call(transport, "ping")).to eq({"ok" => true})
    end

    it "raises when an unexpected response id arrives" do
      messages.concat([
        {"jsonrpc" => "2.0", "id" => 1, "result" => {"ok" => false}}
      ])
      expect { client.call(transport, "ping") }
        .to raise_error(LLM::MCP::MismatchError, /mismatched MCP response id 1/)
    end
  end
end
