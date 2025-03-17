# frozen_string_literal: true

require "webmock/rspec"

RSpec.describe "LLM::OpenAI: embeddings" do
  let(:gemini) { LLM.gemini("") }

  before(:each, :success) do
    stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=")
      .with(headers: {"Content-Type" => "application/json"})
      .to_return(
        status: 200,
        body: fixture("gemini/embeddings/hello_world_embedding.json"),
        headers: {"Content-Type" => "application/json"}
      )
  end

  context "when given a successful response", :success do
    subject(:response) { gemini.embed("Hello, world") }

    it "returns an embedding" do
      expect(response).to be_instance_of(LLM::Response::Embedding)
    end

    it "returns a model" do
      expect(response.model).to eq("text-embedding-004")
    end

    it "has embeddings" do
      expect(response.embeddings).to be_instance_of(Array)
    end
  end
end
