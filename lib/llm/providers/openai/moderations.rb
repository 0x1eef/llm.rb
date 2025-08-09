# frozen_string_literal: true

class LLM::OpenAI
  ##
  # The {LLM::OpenAI::Moderations LLM::OpenAI::Moderations} class provides a moderations
  # object for interacting with [OpenAI's moderations API](https://platform.openai.com/docs/api-reference/moderations).
  # The moderations API can categorize content into different categories, such as
  # hate speech, self-harm, and sexual content. It can also provide a confidence score
  # for each category.
  #
  # @example
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.openai(key: ENV["KEY"])
  #   res = llm.moderations.create input: "I hate you"
  #   mod = res.moderations[0]
  #   print "categories: #{mod.categories}", "\n"
  #   print "scores: #{mod.scores}", "\n"
  #
  # @example
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.openai(key: ENV["KEY"])
  #   res = llm.moderations.create input: URI.parse("https://example.com/image.png")
  #   mod = res.moderations[0]
  #   print "categories: #{mod.categories}", "\n"
  #   print "scores: #{mod.scores}", "\n"
  #
  # @see https://platform.openai.com/docs/api-reference/moderations/create OpenAI docs
  # @see https://platform.openai.com/docs/models#moderation OpenAI moderation models
  class Moderations
    require_relative "response/moderations"

    ##
    # Returns a new Moderations object
    # @param [LLM::Provider] provider
    # @return [LLM::OpenAI::Moderations]
    def initialize(provider)
      @provider = provider
    end

    ##
    # Create a moderation
    # @see https://platform.openai.com/docs/api-reference/moderations/create OpenAI docs
    # @see https://platform.openai.com/docs/models#moderation OpenAI moderation models
    # @param [String, URI, Array<String, URI>] input
    # @param [String, LLM::Model] model The model to use
    # @return [LLM::Response]
    def create(input:, model: "omni-moderation-latest", **params)
      req = Net::HTTP::Post.new("/v1/moderations", headers)
      input = Format::ModerationFormat.new(input).format
      req.body = JSON.dump({input:, model:}.merge!(params))
      res = execute(request: req)
      LLM::Response.new(res).extend(LLM::OpenAI::Response::Moderations)
    end

    private

    [:headers, :execute].each do |m|
      define_method(m) { |*args, **kwargs, &b| @provider.send(m, *args, **kwargs, &b) }
    end
  end
end
