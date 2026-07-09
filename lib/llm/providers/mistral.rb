# frozen_string_literal: true

require_relative "openai" unless defined?(LLM::OpenAI)

module LLM
  ##
  # The Mistral class implements a provider for
  # [Mistral](https://mistral.ai) through its
  # OpenAI-compatible API.
  #
  # @example
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.mistral(key: ENV["KEY"])
  #   ctx = LLM::Context.new(llm)
  #   ctx.talk "Hello"
  #   ctx.messages.select(&:assistant?).each { print "[#{_1.role}]", _1.content, "\n" }
  class Mistral < OpenAI
    require_relative "mistral/request_adapter"
    include Mistral::RequestAdapter

    HOST = "api.mistral.ai"
    BASE_PATH = "/v1/"

    ##
    # @param key (see LLM::Provider#initialize)
    # @param host (see LLM::Provider#initialize)
    # @param base_path (see LLM::Provider#initialize)
    # @return [LLM::Mistral]
    def initialize(host: HOST, base_path: BASE_PATH, **)
      super
    end

    ##
    # @return [Symbol]
    #  Returns the provider's name
    def name
      :mistral
    end

    ##
    # @return [NotImplementedError]
    def images
      raise NotImplementedError
    end

    ##
    # Provides an embedding.
    # @param input (see LLM::Provider#embed)
    # @param model (see LLM::Provider#embed)
    # @param params (see LLM::Provider#embed)
    # @raise (see LLM::Provider#request)
    # @return (see LLM::Provider#embed)
    def embed(input, model: "mistral-embed", **params)
      super
    end

    ##
    # @raise [NotImplementedError]
    def responses
      raise NotImplementedError
    end

    ##
    # @return [LLM::Mistral::Audio]
    def audio
      raise NotImplementedError
    end

    ##
    # @raise [NotImplementedError]
    def files
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
    # @return [String]
    def default_model
      "mistral-large-latest"
    end
  end
end
