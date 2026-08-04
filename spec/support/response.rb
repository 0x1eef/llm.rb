# frozen_string_literal: true

module LLM::ResponseFactory
  ##
  # Builds a real {LLM::Response} with the given choices and usage.
  #
  # This lets specs stub a network-touching call (eg `responses.create`)
  # while still exercising real response objects — real `LLM::Message`
  # choices, a real usage `LLM::Object`, and the real response parsing
  # path — instead of a `double(choices: [...])`.
  #
  # @param [Array<LLM::Message>] choices
  #  The response choices (real messages).
  # @param [Hash, nil] usage
  #  Token usage for the response.
  # @return [LLM::Response]
  def response!(choices:, usage: {})
    body = LLM::Object.from(id: "test", choices:, usage:)
    res = Net::HTTPOK.new("1.1", "200", "OK")
    res.body = body
    res.instance_variable_set(:@read, true)
    LLM::Response.new(LLM::Transport::Response.from(res))
  end
end

RSpec.configure do |config|
  config.include LLM::ResponseFactory
end
