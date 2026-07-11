# frozen_string_literal: true

class LLM::Repl
  ##
  # This class is designed to represent a markdown
  # string (typically from a model's response) as a
  # tree of objects where each object contains a piece
  # of text, and also optional style information for
  # that text (eg bold, underscore, ...)
  class Markdown
    ##
    # @param [String] text
    # @return [LLM::Repl::Markdown]
    def initialize(text)
      @doc = Kramdown::Document.new(text)
      @ast = []
    end

    ##
    # @return [Array<Hash>]
    def ast
      @ast.tap do
        ##
        # Recurisvely travels the markdown document and
        # populates the `@ast` variable along the way.
        # The AST is composed of structured data that
        # carries both text and styling information that
        # is applied by the UI thread.
        walk(@doc.root)

        ##
        # This is required because the AST collects
        # empty nodes towards the end of the tree.
        # If we don't pop them we end up with excessive
        # amount of newlines between turns.
        last = @ast.last
        while last and last[:text].to_s.strip.empty?
          @ast.pop
          last = @ast.last
        end
      end
    end

    private

    ##
    # Recursively walk from the head node to the
    # tail node. This method mutates the `@ast`
    # variable. A future refactor might be worthwhile
    # since this method is implemented with side effects,
    # but it probably could return the ast instead.
    def walk(node, attrs = nil)
      case node.type
      when :root
        node.children.each { walk(_1, attrs) }
      when :text
        emit(node.value.to_s, attrs)
      when :p
        node.children.each { walk(_1, attrs) }
        emit("\n\n", attrs)
      when :header
        emit("\n", attrs)
        node.children.each { walk(_1, Curses::A_BOLD) }
        emit("\n", attrs)
      when :strong
        node.children.each { walk(_1, Curses::A_BOLD) }
      when :em
        node.children.each { walk(_1, Curses::A_UNDERLINE) }
      when :codespan
        emit(node.value, Curses::A_REVERSE)
      when :codeblock
        emit(node.value, Curses::A_REVERSE)
        emit("\n\n", attrs)
      when :br
        emit("\n", attrs)
      else
        node.children.each { walk(_1, attrs) }
      end
    end

    def emit(text, attrs)
      @ast.push({text: text.to_s, attrs:}.compact)
    end
  end
end
