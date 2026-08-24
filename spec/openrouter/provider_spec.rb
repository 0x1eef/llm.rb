# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::OpenRouter" do
  subject(:provider) do
    LLM.openrouter(key: "TOKEN").with(
      "HTTP-Referer" => "https://example.com",
      "X-OpenRouter-Title" => "Example App"
    )
  end

  let(:response_body) do
    JSON.dump(
      id: "chatcmpl-test",
      object: "chat.completion",
      created: 0,
      model: "openrouter/auto",
      choices: [{index: 0, message: {role: "assistant", content: "pong"}, finish_reason: "stop"}],
      usage: {prompt_tokens: 1, completion_tokens: 1, total_tokens: 2}
    )
  end

  it "builds the OpenRouter provider with its API defaults" do
    expect(provider).to be_a(LLM::OpenAI)
    expect(provider.name).to eq(:openrouter)
    expect(provider.default_model).to eq("openrouter/auto")
    expect(provider.instance_variable_get(:@host)).to eq("openrouter.ai")
    expect(provider.instance_variable_get(:@base_path)).to eq("/api/v1")
  end

  it "sends chat completions with app attribution" do
    request = stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
      .with(
        headers: {
          "Authorization" => "Bearer TOKEN",
          "HTTP-Referer" => "https://example.com",
          "X-OpenRouter-Title" => "Example App"
        },
        body: hash_including("model" => "openrouter/auto")
      )
      .to_return(status: 200, headers: {"Content-Type" => "application/json"}, body: response_body)

    response = provider.complete("ping")

    expect(request).to have_been_requested.once
    expect(response.content).to eq("pong")
  end

  it "omits app attribution headers by default" do
    request = stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
      .with do |req|
        names = req.headers.keys.map(&:downcase)
        !names.include?("http-referer") && !names.include?("x-openrouter-title")
      end
      .to_return(status: 200, headers: {"Content-Type" => "application/json"}, body: response_body)

    LLM.openrouter(key: "TOKEN").complete("ping")

    expect(request).to have_been_requested.once
  end

  it "uses an OpenRouter model ID for embeddings" do
    request = stub_request(:post, "https://openrouter.ai/api/v1/embeddings")
      .with(body: hash_including("model" => "openai/text-embedding-3-small"))
      .to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: JSON.dump(
          object: "list",
          model: "openai/text-embedding-3-small",
          data: [{object: "embedding", index: 0, embedding: [0.1, 0.2]}],
          usage: {prompt_tokens: 1, total_tokens: 1}
        )
      )

    response = provider.embed("ping")

    expect(request).to have_been_requested.once
    expect(response.embeddings).to eq([[0.1, 0.2]])
  end

  it "does not expose unsupported OpenAI APIs" do
    %i[files images audio moderations vector_stores].each do |api|
      expect { provider.public_send(api) }.to raise_error(NotImplementedError)
    end
  end
end
