# frozen_string_literal: true

module LLM
  class VoyageAI < Provider
    require_relative "voyageai/error_handler"
    require_relative "voyageai/response_parser"
    HOST = "api.voyageai.com"

    ##
    # @param secret (see LLM::Provider#initialize)
    def initialize(secret, **)
      super(secret, host: HOST, **)
    end

    ##
    # Provides an embedding via VoyageAI per
    # [Anthropic's recommendation](https://docs.anthropic.com/en/docs/build-with-claude/embeddings)
    # @param input (see LLM::Provider#embed)
    # @return (see LLM::Provider#embed)
    def embed(input, **params)
      req = Net::HTTP::Post.new("/v1/embeddings", headers)
      req.body = JSON.dump({input:, model: "voyage-2"}.merge!(params))
      res = request(@http, req)
      Response::Embedding.new(res).extend(response_parser)
    end

    private

    def headers
      {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{@secret}"
      }
    end

    def response_parser
      LLM::VoyageAI::ResponseParser
    end

    def error_handler
      LLM::VoyageAI::ErrorHandler
    end
  end
end
