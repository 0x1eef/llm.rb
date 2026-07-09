# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::Context: mistral", interval: 5 do
  let(:provider) { LLM.mistral(key:) }
  let(:key) { ENV["MISTRAL_SECRET"] || "TOKEN" }
  let(:ctx) { LLM::Context.new(provider, params) }
  let(:params) { {} }

  context LLM::Context do
    include_examples "LLM::Context: completions", :mistral
    include_examples "LLM::Context: text stream", :mistral
    include_examples "LLM::Context: tool stream", :mistral
  end

  context LLM::Function do
    include_examples "LLM::Context: functions", :mistral
  end

  context LLM::Schema do
    include_examples "LLM::Context: schema", :mistral
  end
end
