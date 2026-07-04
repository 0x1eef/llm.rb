# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::Context: ollama" do
  let(:provider) { LLM.ollama(host:) }
  let(:host) { ENV["OLLAMA_HOST"] || "localhost" }
  let(:ctx) { LLM::Context.new(provider, params) }
  let(:params) { {} }

  context LLM::Context do
    include_examples "LLM::Context: completions", :ollama,
                     match_requests_on: [:method],
                     allow_playback_repeats: true
    include_examples "LLM::Context: text stream", :ollama,
                     match_requests_on: [:method],
                     allow_playback_repeats: true
  end

  context LLM::Function do
    let(:params) { {stream: false} }
    include_examples "LLM::Context: functions", :ollama,
                     match_requests_on: [:method],
                     allow_playback_repeats: true
  end

  context LLM::Schema do
    include_examples "LLM::Context: schema", :ollama,
                     match_requests_on: [:method],
                     allow_playback_repeats: true
  end
end
