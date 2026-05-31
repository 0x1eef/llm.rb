# frozen_string_literal: true

class LLM::Transport
  ##
  # The {LLM::Transport::Curb LLM::Transport::Curb} transport is an
  # optional adapter for libcurl via the
  # [curb](https://github.com/taf2/curb) gem.
  #
  # Curb is a C extension around libcurl. It releases the GVL during
  # I/O so other Ruby threads can run while requests are in flight. Its
  # timeout handling is built into libcurl itself — no thread-based
  # timeout library required. It supports HTTP/2, connection reuse, and
  # a wider range of network protocols out of the box.
  #
  # Unlike the built-in Net::HTTP transports, this transport does not
  # require any Ruby standard library HTTP client and can be used on
  # platforms where Net::HTTP is not available or desired.
  #
  # @example
  #   LLM.openai(key: ENV["KEY"], transport: LLM::Transport.curb)
  #   LLM.openai(key: ENV["KEY"], transport: LLM::Transport::Curb)
  #
  # @api private
  class Curb < self
    INTERRUPT_ERRORS = [::IOError, ::EOFError, Errno::EBADF].freeze
    ActiveRequest = Struct.new(:easy, keyword_init: true)

    ##
    # @param [String] host
    # @param [Integer] port
    # @param [Integer] timeout
    # @param [Boolean] ssl
    # @return [LLM::Transport::Curb]
    def initialize(host:, port:, timeout:, ssl:)
      @host = host
      @port = port
      @timeout = timeout
      @ssl = ssl
      @base_uri = URI("#{ssl ? "https" : "http"}://#{host}:#{port}/")
      @monitor = Monitor.new
    end

    ##
    # Returns the current request owner.
    # @return [Object]
    def request_owner
      return Fiber.current unless defined?(::Async)
      Async::Task.current? ? Async::Task.current : Fiber.current
    end

    ##
    # @return [Array<Class<Exception>>]
    def interrupt_errors
      [*INTERRUPT_ERRORS, *optional_interrupt_errors]
    end

    ##
    # Interrupt an active request, if any.
    #
    # Sets the interrupt flag so the on_body callback can raise
    # LLM::Interrupt on the next chunk.
    #
    # @param [Fiber] owner
    # @return [nil]
    def interrupt!(owner)
      request_for(owner) or return
      lock { (@interrupts ||= {})[owner] = true }
    rescue *interrupt_errors
      nil
    end

    ##
    # Returns whether an execution owner was interrupted.
    # @param [Fiber] owner
    # @return [Boolean, nil]
    def interrupted?(owner)
      lock { @interrupts&.delete(owner) }
    end

    ##
    # Performs a request through curb and returns a transport response
    # wrapper so the provider layer can stay transport-agnostic.
    #
    # @param [LLM::Transport::Request] request
    # @param [Fiber] owner
    # @param [LLM::Object, nil] stream
    # @yieldparam [LLM::Transport::Response] response
    # @return [Object]
    def request(request, owner:, stream: nil, &b)
      easy = build_easy(request)
      set_request(ActiveRequest.new(easy:), owner)
      if stream
        perform_streaming(easy, owner, stream)
      elsif b
        res = perform_blocking(easy, owner)
        if LLM::Transport::Response === res
          res.success? ? b.call(res) : res
        else
          res
        end
      else
        perform_blocking(easy, owner)
      end
    ensure
      clear_request(owner)
    end

    ##
    # @return [String]
    def inspect
      "#<#{LLM::Utils.object_id(self)}>"
    end

    private

    attr_reader :host, :port, :timeout, :ssl, :base_uri

    def build_easy(request)
      LLM.require "curb" unless defined?(::Curl)
      easy = ::Curl::Easy.new(request_url(request))
      easy.timeout = timeout
      easy.connect_timeout = timeout
      request.headers.each { |k, v| easy.headers[k] = v }
      easy.follow_location = true
      easy.ssl_verify_peer = false if !ssl
      set_body(easy, request)
      easy
    end

    def request_url(request)
      path = request.path
      return path if path.start_with?("http://", "https://")
      scheme = ssl ? "https" : "http"
      default_port = ssl ? 443 : 80
      authority = port && port.to_i > 0 && port.to_i != default_port \
                    ? "#{host}:#{port}" : host
      "#{scheme}://#{authority}#{path}"
    end

    def set_body(easy, request)
      case request.method
      when "POST"
        easy.post_body = request.body if request.body
      when "PUT"
        easy.put_data = request.body if request.body
      when "DELETE"
        easy.delete = true
      end
    end

    def perform_blocking(easy, owner)
      check_interrupted(owner)
      easy.on_body { |chunk|
        check_interrupted(owner)
        chunk.bytesize
      }
      easy.perform
      build_response(easy)
    end

    def perform_streaming(easy, owner, stream)
      res = nil
      raw_body = +""
      decoder = stream.decoder.new(stream.parser.new(stream.streamer))
      easy.on_body do |chunk|
        raise LLM::Interrupt, "request interrupted" if interrupted?(owner)
        if (res ||= build_response_from_headers(easy))&.success? \
           && res["content-type"].to_s.include?("text/event-stream")
          decoder << chunk
        else
          raw_body << chunk
        end
        chunk.bytesize
      end
      easy.perform
      res ||= build_response(easy)
      if raw_body.empty?
        body = decoder.body
        res.body = (Hash === body || Array === body) \
                     ? LLM::Object.from(body) : body
      else
        res.body = raw_body
      end
      res
    ensure
      decoder&.free
    end

    def build_response(easy)
      LLM::Transport::Response::Curb.new(
        easy.response_code.to_i,
        parse_headers(easy.header_str.to_s),
        easy.body_str.to_s
      )
    end

    def build_response_from_headers(easy)
      return nil if easy.header_str.to_s.empty?
      LLM::Transport::Response::Curb.new(
        easy.response_code.to_i,
        parse_headers(easy.header_str.to_s),
        +""
      )
    end

    def parse_headers(header_str)
      headers = {}
      header_str.each_line do |line|
        line = line.strip
        next if line.empty? || line.start_with?("HTTP/")
        key, value = line.split(/: \s*/, 2)
        headers[key.downcase] = value if key && value
      end
      headers
    end

    def check_interrupted(owner)
      raise LLM::Interrupt, "request interrupted" if interrupted?(owner)
    end

    def request_for(owner)
      lock do
        @requests ||= {}
        @requests[owner]
      end
    end

    def set_request(req, owner)
      lock do
        @requests ||= {}
        @requests[owner] = req
      end
    end

    def clear_request(owner)
      lock { @requests&.delete(owner) }
    end

    def lock(&)
      @monitor.synchronize(&)
    end

    def optional_interrupt_errors
      defined?(::Async::Stop) ? [Async::Stop] : []
    end
  end
end
