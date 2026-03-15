require "bundler/setup"
Bundler.require(:default)

class Websocket
  ##
  # @return [LLM::provider]
  attr_reader :llm

  class Stream
    ##
    # @param [Websocket] sock
    # @return [Websocket::Stream]
    def initialize(conn,sock)
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

  ##
  # @param [LLM::Provider] llm
  # @return [Websocket]
  def initialize(llm)
    @llm = llm
  end

  ##
  # @param [Hash] env
  # @return [Array]
  def call(env)
    Async::WebSocket::Adapters::Rack.open(env) do |conn|
      on_connect conn, LLM::Session.new(llm)
    end || upgrade_required
  end

  def write(conn, message)
    conn.write(message.to_json)
    conn.flush
  end

  private

  def on_connect(conn, sess)
    write(conn, event: "welcome")
    while message = conn.read
      read(conn, sess, message)
    end
  end

  def read(conn, sess, message)
    sess.talk(message.buffer, stream: Stream.new(conn, self))
    write(conn, event: "done")
  rescue => ex
    puts ex.class, ex.message, ex.backtrace
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
end

llm = LLM.openai(key: ENV.fetch("OPENAI_SECRET"))
files = Rack::Files.new(File.expand_path("public", __dir__))

run lambda { |env|
  case env["PATH_INFO"]
  when "/ws" then Websocket.new(llm).call(env)
  when "/" then files.call(env.merge("PATH_INFO" => "/index.html"))
  else files.call(env)
  end
}
