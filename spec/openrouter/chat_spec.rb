# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::Context: openrouter" do
  let(:provider) { LLM.openrouter(key:) }
  let(:llm) { provider }
  let(:key) { ENV["OPENROUTER_API_KEY"] || "TOKEN" }
  let(:ctx) { LLM::Context.new(provider, params) }
  let(:params) { {} }

  context LLM::Context do
    include_examples "LLM::Context: completions", :openrouter
    include_examples "LLM::Context: completions contract", :openrouter
    include_examples "LLM::Context: text stream", :openrouter
    include_examples "LLM::Context: tool stream", :openrouter
  end

  context LLM::Function do
    include_examples "LLM::Context: functions", :openrouter
  end

  context LLM::Schema do
    include_examples "LLM::Context: schema", :openrouter
  end
end