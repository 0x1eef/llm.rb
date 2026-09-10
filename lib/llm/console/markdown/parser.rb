# frozen_string_literal: true

class LLM::Console
  ##
  # Treats HTML and smart punctuation as plain text. Keep
  # each parser registered (so kramdown's sub-parser lists,
  # eg tables, still resolve) but point it at a no-op that
  # emits the matched text literally instead of parsing it.
  class Markdown::Parser < ::Kramdown::Parser::Kramdown
    ##
    # Swap these parser slots for literal-text no-ops.
    LITERAL = %i[span_html block_html smart_quotes typographic_syms]

    def configure_parser
      super
      LITERAL.each { |name| swap(name, :"parse_#{name}") }
    end

    private

    ##
    # Point a registered parser at a no-op that emits its
    # input literally. Keeps the slot in @parsers so tables
    # and other sub-parser lists still resolve.
    # @param [Symbol] name
    # @param [Symbol] method
    def swap(name, method)
      data = @parsers[name]
      @parsers[name] = ::Kramdown::Parser::Kramdown::Data.new(
        name, data.start_re, data.span_start, method
      )
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
      add_text(@src.scan(::Kramdown::Parser::Kramdown::SMART_QUOTES_RE))
    end

    ##
    # Emit the typographic symbol literally instead of mapping.
    def parse_typographic_syms
      add_text(@src.scan(::Kramdown::Parser::Kramdown::TYPOGRAPHIC_SYMS_RE))
    end
  end
end
