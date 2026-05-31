# frozen_string_literal: true

class LLM::Transport::Response
  ##
  # {LLM::Transport::Response::Curb LLM::Transport::Response::Curb}
  # adapts a raw status code, header hash, and body string to the
  # {LLM::Transport::Response LLM::Transport::Response} interface.
  #
  # This is the response wrapper used by the
  # {LLM::Transport::Curb LLM::Transport::Curb} transport.
  class Curb < self
    ##
    # @return [Integer]
    attr_reader :code

    ##
    # @return [Hash]
    attr_reader :headers

    ##
    # @return [String]
    attr_accessor :body

    ##
    # @param [#to_i] code
    # @param [Hash] headers
    # @param [String] body
    # @return [LLM::Transport::Response::Curb]
    def initialize(code, headers = {}, body = +"")
      @code = code.to_i
      @headers = {}
      (headers || {}).each { @headers[_1.to_s.downcase] = _2.to_s }
      @body = body
    end

    ##
    # @param [String] key
    # @return [String, nil]
    def [](key)
      @headers[key.to_s.downcase]
    end

    ##
    # @param [Object, nil] dest
    # @yieldparam [String] chunk
    # @return [void]
    def read_body(dest = nil, &block)
      return @body unless block_given? || dest
      if dest
        dest << @body.to_s
      else
        yield @body.to_s
      end
      @body
    end

    ##
    # @return [Boolean]
    def success?
      code.between?(200, 299)
    end

    ##
    # @return [Boolean]
    def ok?
      code == 200
    end

    ##
    # @return [Boolean]
    def bad_request?
      code == 400
    end

    ##
    # @return [Boolean]
    def unauthorized?
      code == 401
    end

    ##
    # @return [Boolean]
    def forbidden?
      code == 403
    end

    ##
    # @return [Boolean]
    def not_found?
      code == 404
    end

    ##
    # @return [Boolean]
    def rate_limited?
      code == 429
    end

    ##
    # @return [Boolean]
    def server_error?
      code.between?(500, 599)
    end

    ##
    # @return [String]
    def inspect
      "#<#{self.class.name}:0x#{object_id.to_s(16)}" \
        " @code=#{@code} @headers=#{@headers.inspect}>"
    end
  end
end
