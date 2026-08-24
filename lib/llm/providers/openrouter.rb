# frozen_string_literal: true

require_relative "openai" unless defined?(LLM::OpenAI)

module LLM
  ##
  # The OpenRouter class implements a provider for
  # [OpenRouter](https://openrouter.ai) through its OpenAI-compatible API.
  #
  # @example
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.openrouter(key: ENV["KEY"])
  #   ctx = LLM::Context.new(llm)
  #   ctx.talk "Hello"
  class OpenRouter < OpenAI
    HOST = "openrouter.ai"
    BASE_PATH = "/api/v1"

    ##
    # @param key (see LLM::Provider#initialize)
    # @param host (see LLM::Provider#initialize)
    # @param base_path (see LLM::Provider#initialize)
    # @return [LLM::OpenRouter]
    def initialize(host: HOST, base_path: BASE_PATH, **)
      super
    end

    ##
    # @return [Symbol]
    #  Returns the provider's name
    def name
      :openrouter
    end

    ##
    # Provides an embedding.
    # @see https://openrouter.ai/docs/api/api-reference/embeddings/create-embeddings OpenRouter docs
    # @param input (see LLM::Provider#embed)
    # @param model (see LLM::Provider#embed)
    # @param params (see LLM::Provider#embed)
    # @raise (see LLM::Provider#request)
    # @return (see LLM::Provider#embed)
    def embed(input, model: "openai/text-embedding-3-small", **params)
      super
    end

    ##
    # @raise [NotImplementedError]
    def files
      raise NotImplementedError
    end

    ##
    # @raise [NotImplementedError]
    def images
      raise NotImplementedError
    end

    ##
    # @raise [NotImplementedError]
    def audio
      raise NotImplementedError
    end

    ##
    # @raise [NotImplementedError]
    def moderations
      raise NotImplementedError
    end

    ##
    # @raise [NotImplementedError]
    def vector_stores
      raise NotImplementedError
    end

    ##
    # Returns the default model for chat completions
    # @see https://openrouter.ai/docs/guides/routing/routers/auto-router OpenRouter Auto Router
    # @return [String]
    def default_model
      "openrouter/auto"
    end
  end
end
