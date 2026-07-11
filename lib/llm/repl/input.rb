# frozen_string_literal: true

class LLM::Repl
  ##
  # The {LLM::Repl::Input LLM::Repl::Input} class manages
  # the editable input line shown at the bottom of the REPL.
  # @api private
  class Input
    UP        = Curses::Key::UP
    DOWN      = Curses::Key::DOWN
    LEFT      = Curses::Key::LEFT
    RIGHT     = Curses::Key::RIGHT
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
      @cursor = 0
    end

    ##
    # @param [LLM::Repl::Window] window
    # @param [Object] char
    # @return [Symbol, nil]
    def on_char(window, char)
      if EOF.include?(char)
        :exit
      elsif BACKSPACE.include?(char)
        backspace
        :backspace
      elsif ENTER.include?(char)
        :submit
      elsif char == UP
        window.scroll_up
        :up
      elsif char == DOWN
        window.scroll_down
        :down
      elsif char == LEFT
        move_left
        :left
      elsif char == RIGHT
        move_right
        :right
      elsif String === char
        insert(char)
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
    # @return [Integer]
    def cursor
      prompt.length + @cursor
    end

    ##
    # @return [void]
    def move_left
      @cursor = [@cursor - 1, 0].max
    end

    ##
    # @return [void]
    def move_right
      @cursor = [@cursor + 1, @buffer.length].min
    end

    ##
    # @return [String]
    def take
      @buffer.dup.tap do
        @buffer.clear
        @cursor = 0
      end
    end

    private

    def prompt
      "#{@provider}> "
    end

    def insert(char)
      @buffer.insert(@cursor, char)
      @cursor += char.length
    end

    def backspace
      return if @cursor <= 0
      @buffer.slice!(@cursor - 1)
      @cursor -= 1
    end
  end
end
