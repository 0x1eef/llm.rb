# frozen_string_literal: true

class LLM::Repl
  ##
  # The {LLM::Repl::Input LLM::Repl::Input} class manages
  # the editable input line shown at the bottom of the REPL.
  # @api private
  class Input
    include Curses::Key

    ENTERK     = [ENTER, 10, 13]
    BACKSPACEK = [BACKSPACE, 103]
    EOFK       = [nil, 4]

    ##
    # @param [String, Symbol] provider
    # @return [LLM::Repl::Input]
    def initialize(provider)
      @provider = provider
      @buffer = +""
    end

    ##
    # @param [LLM::Repl::Window] window
    # @return [String, nil]
    def readline(window)
      catch(:done) do
        @buffer.clear
        loop do
          window.redraw
          on_char(window, window.getch)
        end
      end
    end

    ##
    # @return [String]
    def to_s
      "#{@provider}> #{@buffer}"
    end

    private

    def on_char(window, char)
      if EOFK.include?(char)
        throw(:done, nil)
      elsif BACKSPACEK.include?(char)
        @buffer.chop!
      elsif ENTERK.include?(char)
        buf = @buffer.dup
        @buffer.clear
        window.redraw
        throw(:done, buf)
      elsif char == UP
        window.scroll_up
      elsif char == DOWN
        window.scroll_down
      elsif String === char
        @buffer << char
      else
        # ???
      end
    end
  end
end
