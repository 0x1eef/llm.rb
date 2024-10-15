# frozen_string_literal: true

module LLM
  ##
  # The Provider class represents a base class for
  # LLM (Language Model) providers
  class Provider
    ##
    # @param [String] secret
    #  The secret key for authentication
    # @param [String]
    #  The host address of the LLM provider
    # @param [Integer] port
    #  The port number
    def initialize(secret, host, port = 443)
      @secret = secret
      @http = Net::HTTP.new(host, port).tap do |http|
        http.use_ssl = true
        http.extend(HTTPClient)
      end
    end

    ##
    # Completes a given prompt using the LLM
    # @param [String] prompt
    #  The input prompt to be completed
    # @raise [NotImplementedError]
    #  When the method is not implemented by a subclass
    def complete(prompt)
      raise NotImplementedError
    end

    private

    ##
    # Prepares a request for authentication
    # @param [Net::HTTP::Request] req
    #  The request to prepare for authentication
    # @raise [NotImplementedError]
    #  (see LLM::Provider#complete)
    def auth(req)
      raise NotImplementedError
    end
  end
end
