# frozen_string_literal: true

require_relative "setup"

RSpec.describe LLM::Tool::Param do
  context "when given enum values for a param" do
    let(:tool) do
      Class.new(LLM::Tool) do
        name "create-image"
        description "Create a generated image"
        param :provider, String, "The provider", enum: %w[openai gemini], default: "gemini"
      end
    end

    subject(:provider_param) { tool.function.params.properties[:provider] }

    it "serializes the enum as a flat array" do
      expect(provider_param.to_h[:enum]).to eq(%w[openai gemini])
    end

    it "preserves the default value" do
      expect(provider_param.to_h[:default]).to eq("gemini")
    end
  end
end
