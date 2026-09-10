# frozen_string_literal: true

class LLM::Console
  ##
  # Treats HTML and smart punctuation as plain text. Keep
  # each parser registered (so kramdown's sub-parser lists,
  # eg tables, still resolve) but point it at a no-op that
  # emits the matched text literally instead of parsing it.
  #
  # Tables are enabled but only match when a header row is
  # followed by a delimiter row (---). This breaks from
  # default kramdown behavior which parses |foo| as a
  # table.
  class Markdown::Parser < ::Kramdown::Parser::Kramdown
    ##
    # Swap these parser slots for literal-text no-ops.
    LITERAL = %i[span_html block_html smart_quotes typographic_syms]

    ##
    # A table starts with a header row that holds a pipe and
    # a delimiter row (`---`). A lone `|foo|` in prose is not
    # a table, so this matches only when a delimiter follows.
    TABLE_START = /^[ \t]*(?=\S)#{TABLE_LINE}(?=#{TABLE_SEP_LINE})/m

    def configure_parser
      super
      LITERAL.each { |name| swap(name, :"parse_#{name}") }
      swap_table!
    end

    private

    ##
    # Replace a parser method with a no-op that emits its
    # matched input literally, keeping the slot registered.
    # @param [Symbol] name
    # @param [Symbol] method
    def swap(name, method)
      data = @parsers[name]
      @parsers[name] = Data.new(name, data.start_re, data.span_start, method)
    end

    ##
    # Use a stricter start regexp for the table parser so bare
    # pipe lines are not misread as tables, while kramdown's
    # own parse_table still renders real tables.
    def swap_table!
      data = @parsers[:table]
      @parsers[:table] = Data.new(:table, TABLE_START, data.span_start, data.method)
    end

    ##
    # Emit the matched HTML tag literally. Falls back to the
    # rest of the `<...` run when there is no closing `>`.
    def parse_span_html
      text = @src.scan_until(/>/)
      add_text(text || @src.scan(/<[^>]*/))
    end

    ##
    # Emit the matched HTML line literally.
    def parse_block_html
      add_text(@src.scan(/[^\n]*/))
    end

    ##
    # Emit the smart quote literally instead of substituting.
    def parse_smart_quotes
      add_text(@src.scan(SMART_QUOTES_RE))
    end

    ##
    # Emit the typographic symbol literally instead of mapping.
    def parse_typographic_syms
      add_text(@src.scan(TYPOGRAPHIC_SYMS_RE))
    end
  end
end
