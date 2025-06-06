# frozen_string_literal: true

module LLM
  ##
  # The Ollama class implements a provider for [Ollama](https://ollama.ai/).
  #
  # This provider supports a wide range of models, it is relatively
  # straight forward to run on your own hardware, and includes multi-modal
  # models that can process images and text. See the example for a demonstration
  # of a multi-modal model by the name `llava`
  #
  # @example
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.ollama(nil)
  #   bot = LLM::Bot.new(llm, model: "llava")
  #   bot.chat LLM::File("/images/capybara.png")
  #   bot.chat "Describe the image"
  #   bot.messages.select(&:assistant?).each { print "[#{_1.role}]", _1.content, "\n" }
  class Ollama < Provider
    require_relative "ollama/error_handler"
    require_relative "ollama/format"
    require_relative "ollama/stream_parser"
    require_relative "ollama/response_parser"
    require_relative "ollama/models"

    include Format

    HOST = "localhost"

    ##
    # @param key (see LLM::Provider#initialize)
    def initialize(**)
      super(host: HOST, port: 11434, ssl: false, **)
    end

    ##
    # Provides an embedding
    # @param input (see LLM::Provider#embed)
    # @param model (see LLM::Provider#embed)
    # @param params (see LLM::Provider#embed)
    # @raise (see LLM::Provider#request)
    # @return (see LLM::Provider#embed)
    def embed(input, model: default_model, **params)
      params   = {model:}.merge!(params)
      req      = Net::HTTP::Post.new("/v1/embeddings", headers)
      req.body = JSON.dump({input:}.merge!(params))
      res      = execute(request: req)
      Response::Embedding.new(res).extend(response_parser)
    end

    ##
    # Provides an interface to the chat completions API
    # @see https://github.com/ollama/ollama/blob/main/docs/api.md#generate-a-chat-completion Ollama docs
    # @param prompt (see LLM::Provider#complete)
    # @param params (see LLM::Provider#complete)
    # @example (see LLM::Provider#complete)
    # @raise (see LLM::Provider#request)
    # @raise [LLM::Error::PromptError]
    #  When given an object a provider does not understand
    # @return (see LLM::Provider#complete)
    def complete(prompt, params = {})
      params = {role: :user, model: default_model, stream: true}.merge!(params)
      params = [params, {format: params[:schema]}, format_tools(params)].inject({}, &:merge!).compact
      role, stream = params.delete(:role), params.delete(:stream)
      params[:stream] = true if stream.respond_to?(:<<) || stream == true
      req = Net::HTTP::Post.new("/api/chat", headers)
      messages = [*(params.delete(:messages) || []), LLM::Message.new(role, prompt)]
      body = JSON.dump({messages: [format(messages)].flatten}.merge!(params))
      set_body_stream(req, StringIO.new(body))
      res = execute(request: req, stream:)
      Response::Completion.new(res).extend(response_parser)
    end

    ##
    # Provides an interface to Ollama's models API
    # @see https://github.com/ollama/ollama/blob/main/docs/api.md#list-local-models Ollama docs
    # @return [LLM::Ollama::Models]
    def models
      LLM::Ollama::Models.new(self)
    end

    ##
    # @return (see LLM::Provider#assistant_role)
    def assistant_role
      "assistant"
    end

    ##
    # Returns the default model for chat completions
    # @see https://ollama.com/library/qwen3 qwen3
    # @return [String]
    def default_model
      "qwen3:latest"
    end

    private

    def headers
      (@headers || {}).merge(
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{@key}"
      )
    end

    def response_parser
      LLM::Ollama::ResponseParser
    end

    def stream_parser
      LLM::Ollama::StreamParser
    end

    def error_handler
      LLM::Ollama::ErrorHandler
    end
  end
end
