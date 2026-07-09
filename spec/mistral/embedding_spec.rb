# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::Mistral: embeddings" do
  let(:mistral) { LLM.mistral(key:) }
  let(:key) { ENV["MISTRAL_SECRET"] || "TOKEN" }

  context "when given a successful response",
          vcr: {cassette_name: "mistral/embeddings/successful_response"} do
    subject(:response) { mistral.embed("Hello, world") }

    it "returns an embedding" do
      expect(response).to be_instance_of(LLM::Response)
    end

    it "returns a model" do
      expect(response.model).to eq("mistral-embed")
    end

    it "has embeddings" do
      expect(response.embeddings).to be_instance_of(Array)
    end
  end
end
