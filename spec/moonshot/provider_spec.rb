# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::Moonshot" do
  subject(:provider) { LLM.moonshot(key: "TOKEN") }

  it "builds the Moonshot provider with its API defaults" do
    expect(provider).to be_a(LLM::OpenAI)
    expect(provider.name).to eq(:moonshot)
    expect(provider.default_model).to eq("kimi-k3")
    expect(provider.instance_variable_get(:@host)).to eq("api.moonshot.ai")
    expect(provider.instance_variable_get(:@base_path)).to eq("/v1")
  end

  it "sends chat completions to the Kimi endpoint" do
    request = stub_request(:post, "https://api.moonshot.ai/v1/chat/completions")
      .to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: JSON.dump(
          id: "chatcmpl-test",
          object: "chat.completion",
          created: 0,
          model: "kimi-k3",
          choices: [{index: 0, message: {role: "assistant", content: "pong"}, finish_reason: "stop"}],
          usage: {prompt_tokens: 1, completion_tokens: 1, total_tokens: 2}
        )
      )

    response = provider.complete("ping")

    expect(request).to have_been_requested.once
    expect(response.content).to eq("pong")
  end

  it "does not expose unsupported OpenAI APIs" do
    %i[images audio moderations responses vector_stores].each do |api|
      expect { provider.public_send(api) }.to raise_error(NotImplementedError)
    end
  end
end
