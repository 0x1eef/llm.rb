# frozen_string_literal: true

class LLM::Repl
  ##
  # The {LLM::Repl::Input LLM::Repl::Input} class manages
  # the editable input line shown at the bottom of the REPL.
  # @api private
  class Input
    UP        = Curses::Key::UP
    DOWN      = Curses::Key::DOWN
    ENTER     = [Curses::Key::ENTER, 10, 13]
    BACKSPACE = [Curses::Key::BACKSPACE, 127]
    EOF       = [nil, 4]

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
          on_char(window, window.getch)
          window.redraw
        end
      end
    end

    ##
    # @return [String]
    def to_s
      "> #{@buffer}"
    end

    private

    def on_char(window, char)
      if EOF.include?(char)
        throw(:done, nil)
      elsif BACKSPACE.include?(char)
        @buffer.chop!
      elsif ENTER.include?(char)
        buf = @buffer.dup
        @buffer.clear
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
