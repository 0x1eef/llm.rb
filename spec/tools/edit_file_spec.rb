# frozen_string_literal: true

require "tmpdir"
require "setup"
require "llm/tools/edit-file"

RSpec.describe LLM::Tool::EditFile do
  let(:tool) { described_class.new }
  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, "sample.txt") }

  after { FileUtils.remove_entry(dir) }

  describe "#call" do
    context "when replacing a literal snippet" do
      before do
        write("hello world")
        tool.call(path:, before: "hello", after: "goodbye", expected_count: 1)
      end

      it "replaces the matched text" do
        expect(File.read(path)).to eq("goodbye world")
      end
    end

    context "when the before snippet contains regex metacharacters" do
      before do
        write("a +size: 28px;\nb")
        tool.call(path:, before: "+size: 28px;", after: "font-size: 20px;")
      end

      it "treats the snippet literally" do
        expect(File.read(path)).to eq("a font-size: 20px;\nb")
      end
    end

    context "when the snippet spans multiple lines" do
      let(:content) do
        <<~CSS
          main {
            width: min(860px, calc(100% - 32px));
            margin: 0 auto;
            padding: 56px 0 80px;
          }
        CSS
      end

      before do
        write(content)
        tool.call(
          path:,
          before: "main {\n  width: min(860px, calc(100% - 32px));",
          after: "main {\n  max-width: 726px;"
        )
      end

      it "replaces across lines" do
        expect(File.read(path)).to eq(
          "main {\n  max-width: 726px;\n  margin: 0 auto;\n  padding: 56px 0 80px;\n}\n"
        )
      end
    end

    context "when the replacement contains regex metacharacters" do
      before do
        write("a.b[c]")
        tool.call(path:, before: "a.b[c]", after: "x*(y)")
      end

      it "keeps the replacement literal" do
        expect(File.read(path)).to eq("x*(y)")
      end
    end

    context "when the replacement contains backslash sequences" do
      before do
        write("foo")
        tool.call(path:, before: "foo", after: "\\1 \\&")
      end

      it "keeps the backslash sequences literal" do
        expect(File.read(path)).to eq("\\1 \\&")
      end
    end

    context "when the expected count matches multiple occurrences" do
      before do
        write("x foo y foo z")
        tool.call(path:, before: "foo", after: "bar", expected_count: 2)
      end

      it "replaces the first occurrence" do
        expect(File.read(path)).to eq("x bar y foo z")
      end
    end

    context "when the remaining matches fall short of the expected count" do
      before do
        write("x foo y foo z")
        tool.call(path:, before: "foo", after: "bar", expected_count: 2)
      end

      it "raises an error" do
        expect {
          tool.call(path:, before: "foo", after: "bar", expected_count: 2)
        }.to raise_error("expected 2 match(es), found 1")
      end
    end

    context "when the match count differs from the expected count" do
      before { write("foo") }

      it "raises an error" do
        expect {
          tool.call(path:, before: "foo", after: "bar", expected_count: 2)
        }.to raise_error("expected 2 match(es), found 1")
      end
    end

    context "when returning a result" do
      before { write("foo") }

      let(:result) { tool.call(path:, before: "foo", after: "bar") }

      it "returns the number of replacements made" do
        expect(result).to eq(ok: true, replaced: 1)
      end
    end

    context "when applying edits in sequence on the same file" do
      before do
        write(<<~CSS)
          /* Base */
          * {
            box-sizing: border-box;
          }

          body {
            font-family: sans-serif;
          }

          main {
            width: min(860px, calc(100% - 32px));
            margin: 0 auto;
            padding: 56px 0 80px;
          }

          .home-showcase {
            width: min(726px, calc(100% - 32px));
            margin: 0 auto;
            padding: 40px 0 96px;
          }

          .logo-page {
            display: flex;
          }
        CSS
      end

      before do
        tool.call(path:, before: "/* Base */\n* {\n  box-sizing: border-box;\n}\n\nbody {",
                       after: "/* Base */\n* {\n  box-sizing: border-box;\n}\n\nhtml {\n  scrollbar-gutter: stable both-edges;\n}\n\nbody {")
        tool.call(path:, before: "main {\n  width: min(860px, calc(100% - 32px));",
                       after: "main {\n  max-width: 726px;")
        tool.call(path:, before: ".home-showcase {\n  width: min(726px, calc(100% - 32px));\n  margin: 0 auto;\n  padding: 40px 0 96px;\n}",
                       after: ".home-showcase {\n  margin: 0 auto;\n  padding: 40px 0 45px 0;\n}")
      end

      it "applies every edit exactly once and preserves the rest" do
        content = File.read(path)
        expect(content.scan("scrollbar-gutter").length).to eq(1)
        expect(content.scan("max-width: 726px").length).to eq(1)
        expect(content.scan("padding: 40px 0 45px").length).to eq(1)
        expect(content.scan(".logo-page {").length).to eq(1)
      end
    end

    def write(content)
      File.write(path, content)
    end
  end
end
