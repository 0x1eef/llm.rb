# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::OpenAI::Responses" do
  let(:token) { ENV["LLM_SECRET"] || "TOKEN" }
  let(:provider) { LLM.openai(token) }

  context "when given a successful creation",
          vcr: {cassette_name: "openai/responses/successful_creation"} do
    subject { provider.responses.create("Hello", :developer) }

    it "is successful" do
      is_expected.to be_instance_of(LLM::Response::Output)
    end

    it "has outputs" do
      is_expected.to have_attributes(
        outputs: [instance_of(LLM::Message)]
      )
    end
  end

  context "when given a successful get",
          vcr: {cassette_name: "openai/responses/successful_get"} do
    let(:response) { provider.responses.create("Hello", :developer) }
    subject { provider.responses.get(response) }

    it "is successful" do
      is_expected.to be_instance_of(LLM::Response::Output)
    end

    it "has outputs" do
      is_expected.to have_attributes(
        outputs: [instance_of(LLM::Message)]
      )
    end
  end

  context "when given a successful deletion",
          vcr: {cassette_name: "openai/responses/successful_deletion"} do
    let(:response) { provider.responses.create("Hello", :developer) }
    subject { provider.responses.delete(response) }

    it "is successful" do
      is_expected.to have_attributes(
        deleted: true
      )
    end
  end
end
