# frozen_string_literal: true

require "setup"

RSpec.describe LLM::Provider do
  context "with openai" do
    let(:provider) { LLM.openai(key: ENV["OPENAI_SECRET"]) }

    context "when given the with method" do
      subject { provider.send(:headers) }

      before do
        provider
          .with(headers: {"OpenAI-Organization" => "llmrb"})
          .with(headers: {"OpenAI-Project" => "llmrb/llm"})
      end

      it "adds headers" do
        is_expected.to include(
          "OpenAI-Organization" => "llmrb",
          "OpenAI-Project" => "llmrb/llm"
        )
      end
    end

    describe "#key?" do
      context "when given a key resolved via environment" do
        let(:key) { "sk-from-env" }
        before { ENV["OPENAI_API_KEY"] = key }
        after { ENV.delete("OPENAI_API_KEY")  }
        subject { LLM.openai.key? }
        it { is_expected.to be(true) }
      end

      context "when given an empty string as a key" do
        subject { LLM.openai(key: "    ").key? }
        it { is_expected.to be(false) }
      end

      context "when given an API key" do
        subject { LLM.openai(key: "sk-12345").key? }
        it { is_expected.to be(true) }
      end
    end
  end

  context "with bedrock" do
    subject(:provider) do
      LLM.bedrock(
        access_key_id: "AKIA_TEST",
        secret_access_key: "SECRET",
        region: "us-east-1"
      )
    end

    it "builds a Bedrock provider" do
      expect(provider).to be_a(LLM::Bedrock)
      expect(provider.name).to eq(:bedrock)
    end

    context "when credentials are resolved from the environment" do
      let(:access_key_id) { "AKIA_ENV" }
      let(:secret_access_key) { "SECRET_ENV" }
      let(:region) { "eu-west-1" }

      before do
        ENV["AWS_ACCESS_KEY_ID"] = access_key_id
        ENV["AWS_SECRET_ACCESS_KEY"] = secret_access_key
        ENV["AWS_REGION"] = region
      end
      after do
        ENV.delete("AWS_ACCESS_KEY_ID")
        ENV.delete("AWS_SECRET_ACCESS_KEY")
        ENV.delete("AWS_REGION")
      end

      subject { LLM.bedrock.key? }
      it { is_expected.to be(true) }
    end

    context "when credentials are missing" do
      before do
        ENV.delete("AWS_ACCESS_KEY_ID")
        ENV.delete("AWS_SECRET_ACCESS_KEY")
      end
      after do
        ENV.delete("AWS_ACCESS_KEY_ID")
        ENV.delete("AWS_SECRET_ACCESS_KEY")
      end

      it "raises an ArgumentError" do
        expect { LLM.bedrock }.to raise_error(ArgumentError, "you must provide an API key")
      end
    end
  end

  context "with a transport class" do
    it "builds a transport from the provider settings" do
      provider = LLM.openai(key: "test", transport: LLM::Transport.net_http_persistent)
      expect(provider.send(:transport)).to be_a(LLM::Transport::PersistentHTTP)
    end
  end

  context "#interrupt!" do
    let(:provider) { LLM.openai(key: "test") }
    let(:owner) { Fiber.current }

    it "finishes an active transient request" do
      http = Net::HTTP.new("example.com")
      allow(http).to receive(:active?).and_return(true)
      allow(http).to receive(:finish)
      req = LLM::Transport::HTTP::ActiveRequest.new(client: http)
      provider.send(:transport).send(:set_request, req, owner)
      provider.interrupt!(owner)
      expect(http).to have_received(:finish)
    end

    it "finishes an active persistent connection" do
      persistent_class = if defined?(Net::HTTP::Persistent)
        Net::HTTP::Persistent
      else
        stub_const("Net::HTTP::Persistent", Class.new)
      end
      transport = LLM::Transport::PersistentHTTP.new(host: "api.openai.com", port: 443, timeout: 60, ssl: true)
      provider = LLM.openai(key: "test", transport:)
      client = persistent_class.allocate
      connection = double(:connection, http: nil)
      allow(client).to receive(:finish)
      req = LLM::Transport::PersistentHTTP::ActiveRequest.new(client:, connection:)
      provider.send(:transport).send(:set_request, req, owner)
      provider.interrupt!(owner)
      expect(client).to have_received(:finish).with(connection)
    end
  end
end
