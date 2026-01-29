# frozen_string_literal: true

require_relative "setup"

RSpec.describe LLM::Object do
  describe ".from" do
    let(:obj) do
      described_class.from(
        "user" => {
          "name" => "Ava",
          "tags" => ["a", {"k" => 1}]
        },
        "active" => true
      )
    end

    it "wraps nested hashes and arrays" do
      expect(obj).to be_a(described_class)
      expect(obj.user).to be_a(described_class)
      expect(obj.user.name).to eq("Ava")
      expect(obj.user.tags[1]).to be_a(described_class)
      expect(obj.user.tags[1].k).to eq(1)
    end
  end

  describe "key access" do
    let(:obj) { described_class.from("foo" => "bar", :baz => 42) }

    it "provides indifferent access" do
      expect(obj["foo"]).to eq("bar")
      expect(obj[:foo]).to eq("bar")
      expect(obj["baz"]).to eq(42)
      expect(obj[:baz]).to eq(42)
    end

    it "provides method access" do
      expect(obj.foo).to eq("bar")
      expect(obj.baz).to eq(42)
    end

    it "returns nil for missing keys" do
      expect(obj.nope).to be_nil
      expect(obj["nope"]).to be_nil
    end
  end

  describe "#[]=" do
    let(:obj) { described_class.new }

    before { obj[:answer] = 42 }

    it "stores values using string keys" do
      expect(obj["answer"]).to eq(42)
      expect(obj.keys).to eq(["answer"])
    end
  end

  describe "#to_h and #to_hash" do
    let(:obj) { described_class.from("a" => 1, "b" => 2) }
    let(:h) { obj.to_h }
    let(:t) { obj.to_hash }

    it "returns a duplicate of the underlying hash" do
      expect(h).to eq("a" => 1, "b" => 2)
      expect(t).to eq(a: 1, b: 2)
      expect(h).to_not be(obj.to_h)
    end
  end

  describe "#respond_to?" do
    let(:obj) { described_class.from("foo" => "bar") }

    it "returns true for keys and methods" do
      expect(obj.respond_to?(:foo)).to be(true)
      expect(obj.respond_to?(:to_h)).to be(true)
    end
  end

  describe "#fetch" do
    let(:obj) { described_class.from("foo" => "bar") }

    context "when the key exists" do
      it "returns the value for string keys" do
        expect(obj.fetch("foo")).to eq("bar")
      end

      it "returns the value for symbol keys" do
        expect(obj.fetch(:foo)).to eq("bar")
      end
    end

    context "when the key is missing" do
      it "raises KeyError" do
        expect { obj.fetch("nope") }.to raise_error(KeyError)
      end

      it "returns the default value when given" do
        expect(obj.fetch("nope", "default")).to eq("default")
      end
    end
  end

  describe "Enumerable" do
    let(:obj) { described_class.from("a" => 1, "b" => 2, "c" => 3) }

    context "when iterating" do
      let(:pairs) do
        [].tap { |arr| obj.each { |k, v| arr << [k, v] } }
      end

      it "yields key-value pairs" do
        expect(pairs).to contain_exactly(["a", 1], ["b", 2], ["c", 3])
      end
    end

    context "when using enumerable helpers" do
      let(:mapped) { obj.map { |k, v| "#{k}=#{v}" } }
      let(:selected) { obj.select { |_, v| v.odd? } }

      it "supports map" do
        expect(mapped).to contain_exactly("a=1", "b=2", "c=3")
      end

      it "supports select" do
        expect(selected).to contain_exactly(["a", 1], ["c", 3])
      end
    end
  end
end
