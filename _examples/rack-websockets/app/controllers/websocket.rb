# frozen_string_literal: true

module Controller
  class Websocket < Base
    def call
      Async::WebSocket::Adapters::Rack.open(request.env) do |conn|
        on_connect conn, llm, LLM::Session.new(llm, model:, tools:)
      end || upgrade_required
    end

    def write(conn, message)
      conn.write(message.to_json)
      conn.flush
    end

    private

    def on_connect(conn, llm, sess)
      write(conn, event: "welcome", provider: llm.class.to_s, model: sess.model)
      while (message = conn.read)
        read(conn, sess, message)
      end
    end

    def read(conn, sess, message)
      stream = Stream.new(conn, self)
      write(conn, event: "status", message: "Thinking…")
      if sess.messages.empty?
        sess.talk(initial_prompt(message), stream:)
      else
        sess.talk(message.buffer, stream:)
      end
      while sess.functions.any?
        functions = sess.functions
        write(conn, event: "status", message: tool_status(functions))
        sess.talk(functions.map(&:call), stream:)
      end
      write(conn, event: "status", message: "Done")
      write(conn, event: "done")
    rescue StandardError => e
      pp e
      write(conn, event: "status", message: "Error")
      write(conn, event: "error")
    end

    def upgrade_required
      [
        426,
        {
          "content-type" => "text/plain",
          "upgrade" => "websocket"
        },
        ["Expected a WebSocket upgrade request\n"]
      ]
    end

    def tool_status(functions)
      names = functions.map(&:name).uniq.join(", ")
      "Running #{names}…"
    end

    def tools
      [Tool::CreateImage]
    end

    def instructions
      "URLs returned by the create-image tool must be shown inline " \
      "and relative to the current domain instead of sandbox:/"
    end

    def initial_prompt(message)
      LLM::Prompt.new(llm) do
        _1.system instructions
        _1.user message.buffer
      end
    end
  end

  class Websocket::Stream
    def initialize(conn, sock)
      @conn = conn
      @sock = sock
    end

    def <<(chunk)
      @sock.write(@conn, event: "delta", message: chunk.to_s)
    end
  end
end
