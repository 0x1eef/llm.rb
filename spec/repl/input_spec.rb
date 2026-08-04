# frozen_string_literal: true

require "setup"
require "llm/repl"

RSpec.describe LLM::Repl::Input do
  let(:llm) { LLM.deepseek(key: ENV["test"]) }
  let(:repl) { LLM::Repl.new(agent:) }
  let(:agent) { LLM::Agent.new(llm) }
  let(:input) { described_class.new(repl) }

  describe "#restore" do
    let(:buffer) { "" }
    let(:copy) { "" }
    let(:cursor) { 0 }

    before do
      set_buffer(buffer)
      input.instance_variable_set(:@copy, copy)
      input.instance_variable_set(:@cursor, [0, cursor])
    end

    context "when we're at the end of the string" do
      let(:buffer) { +"hello" }
      let(:copy) { " world" }
      let(:cursor) { buffer.size }

      it "appends to the end of the string" do
        input.restore
        expect(input.buffer).to eq("hello world")
      end
    end

    context "when we're inside the string " do
      let(:buffer) { +"hello" }
      let(:copy) { " world" }
      let(:cursor) { 3 }

      it "inserts the string in-place" do
        input.restore
        expect(input.buffer).to eq("hel worldlo")
      end
    end
  end

  describe "#set" do
    before { allow(Curses).to receive(:cols).and_return(30) }

    let(:text) { "" }
    let(:rows) { input.instance_variable_get(:@rows) }

    before { input.send(:set, text:) }

    context "when given a long line" do
      let(:text) { "this is a rather long sentence that wraps onto several lines" }

      it "wraps the line into display rows" do
        expect(rows.size).to be > 1
        expect(rows.map(&:to_s).join(" ")).to eq(text)
      end

      it "flattens back to the original text" do
        expect(input.take).to eq(text)
      end
    end

    context "when given real newlines" do
      let(:text) { "line one\nline two\nline three" }

      it "keeps each line as a row" do
        expect(rows.map(&:to_s)).to eq(["line one", "line two", "line three"])
      end
    end

    context "when given a literal backslash-n" do
      let(:text) { 'a\nb' }

      it "treats it as text rather than a break" do
        expect(rows.map(&:to_s)).to eq(['a\nb'])
      end
    end

    context "when given multiple lines" do
      let(:text) { "line one\nline two" }

      it "places the cursor at the end of the last row" do
        expect(input.instance_variable_get(:@cursor)).to eq([1, 8])
      end
    end
  end

  describe "#delete" do
    before { allow(Curses).to receive(:cols).and_return(149) }

    context "when deleting everything" do
      before { input.send(:set, text: "line one\nline two") }

      it "consumes the break and empties the input" do
        input.instance_variable_set(:@cursor, [0, 0])
        17.times { input.send(:delete) }
        expect(input.take).to eq("")
      end
    end
  end

  describe "#insert auto-wrap" do
    before { allow(Curses).to receive(:cols).and_return(149) }

    it "wraps at word boundaries instead of cutting words" do
      message = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, " \
                "sed do eiusmod tempor incididunt ut labore et dolore magna " \
                "aliqua."
      message.each_char { |char| input.on_char(nil, char, 0) }
      text = input.take
      ##
      # The input may only replace spaces with newlines to wrap.
      # Restoring those newlines back to spaces must reproduce the
      # original message, which fails if a word was cut in half.
      expect(text.gsub("\n", " ")).to eq(message)
    end

    it "preserves newlines from pasted text" do
      message = "line one\nline two\nline three"
      message.each_char { |char| input.on_char(nil, char, 0) }
      expect(input.take).to eq(message)
    end

    it "keeps auto-wraps out of the taken message" do
      long = "some words to wrap " * 20
      long.each_char { |char| input.on_char(nil, char, 0) }
      text = input.take
      expect(text).to_not include("\r")
      expect(text).to_not match(/\S\n\S/)
    end
  end

  ##
  # Sets the input rows to a single row containing the given text.
  # @param [String] string
  # @return [void]
  def set_buffer(string)
    row = LLM::Repl::Input::Row.new
    string.each_char { |char| row.chars << LLM::Repl::Input::Char.new(char) }
    input.instance_variable_set(:@rows, [row])
  end
end
