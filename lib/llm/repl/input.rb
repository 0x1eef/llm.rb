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
    EOF       = [4]

    ##
    # @param [LLM::Agent] agent
    # @return [LLM::Repl::Input]
    def initialize(agent)
      @agent = agent
      @provider = agent.llm.name
      @buffer = +""
    end

    ##
    # @param [LLM::Repl::Window] window
    # @param [Object] char
    # @return [Symbol, nil]
    def on_char(window, char)
      if EOF.include?(char)
        :exit
      elsif BACKSPACE.include?(char)
        @buffer.chop!
        :backspace
      elsif ENTER.include?(char)
        :submit
      elsif char == UP
        window.scroll_up
        :up
      elsif char == DOWN
        window.scroll_down
        :down
      elsif String === char
        @buffer << char
        :char
      else
        nil
      end
    end

    ##
    # @return [String]
    def to_s
      "#{@provider}> #{@buffer}"
    end

    ##
    # @return [String]
    def take
      @buffer.dup.tap { @buffer.clear }
    end

    private
  end
end
