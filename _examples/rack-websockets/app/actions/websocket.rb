# frozen_string_literal: true

module Actions
  class Websocket
    ##
    # @param [Hash<Symbol, LLM::Provider>] llms
    #  A hashmap of LLM::Provider objects
    # @return [Actions::Websocket]
    def initialize(llms)
      @llms = llms
    end

    ##
    # Maintains a websocket connection with a client
    # @return [Array]
    def call(env)
      params = Rack::Request.new(env).params || {}
      name = (params["provider"] || :openai).to_sym
      Async::WebSocket::Adapters::Rack.open(env) do |conn|
        llm = @llms[name]
        on_connect conn, llm, LLM::Session.new(llm, tools:)
      end || upgrade_required
    end

    ##
    # Writes to the websocket
    # @return [void]
    def write(conn, message)
      conn.write(message.to_json)
      conn.flush
    end

    private

    def on_connect(conn, llm, sess)
      sess.talk(sess.prompt { _1.system instructions })
      write(conn, event: "welcome", provider: llm.class.to_s)
      while (message = conn.read)
        read(conn, sess, message)
      end
    end

    def read(conn, sess, message)
      stream = Stream.new(conn, self)
      write(conn, event: "status", message: "Thinking…")
      sess.talk(message.buffer, stream:)
      while sess.functions.any?
        functions = sess.functions
        write(conn, event: "status", message: tool_status(functions))
        sess.talk(functions.map(&:call), stream:)
      end
      write(conn, event: "status", message: "Done")
      write(conn, event: "done")
    rescue StandardError
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
      [Tools::CreateImage]
    end

    def instructions
      "URLs returned by the create-image tool must be shown inline " \
      "and relative to the current domain instead of sandbox:/"
    end
  end

  class Websocket::Stream
    ##
    # @param [Websocket] sock
    # @return [Websocket::Stream]
    def initialize(conn, sock)
      @conn = conn
      @sock = sock
    end

    ##
    # @param [String] chunk
    # @return void
    def <<(chunk)
      @sock.write(@conn, event: "delta", message: chunk.to_s)
    end
  end
end
