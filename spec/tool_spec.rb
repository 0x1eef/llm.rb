# frozen_string_literal: true

require "setup"

RSpec.describe LLM::Tool do
  before(:each) do
    described_class.clear_registry!
  end

  let(:shell) do
    Class.new(described_class) do
      name "shell"
      description "run shell commands"
    end
  end

  let(:weather) do
    Class.new(described_class) do
      name "weather"
      description "show a weather report"
    end
  end

  describe ".registry" do
    subject { described_class.registry }

    context "when given the shell tool" do
      before { shell }
      it { is_expected.to eq([shell]) }
    end

    context "when given the weather tool" do
      before { weather }
      it { is_expected.to eq([weather]) }
    end

    context "when given the weather and shell tools" do
      before { [weather, shell] }
      it { is_expected.to eq([weather, shell]) }
    end

    context "when given an inheritance chain" do
      let(:base) { Class.new(described_class) }
      let(:shell) do
        Class.new(base) do
          name "shell"
          description "run shell commands"
        end
      end

      before { [base, shell] }

      it "includes the tool with a definition" do
        is_expected.to eq([shell])
      end
    end
  end
end
