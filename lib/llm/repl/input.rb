# frozen_string_literal: true

class LLM::Repl
  ##
  # The {LLM::Repl::Input LLM::Repl::Input} class manages
  # the editable input line shown at the bottom of the REPL.
  # @api private
  class Input
    CTRL = {
      A: Curses::KEY_CTRL_A,
      E: Curses::KEY_CTRL_E,
      F: Curses::KEY_CTRL_F,
      K: Curses::KEY_CTRL_K,
      Y: Curses::KEY_CTRL_Y,
      D: Curses::KEY_CTRL_D
    }

    UP        = Curses::Key::UP
    DOWN      = Curses::Key::DOWN
    LEFT      = Curses::Key::LEFT
    RIGHT     = Curses::Key::RIGHT
    ENTER     = [Curses::Key::ENTER, 10, 13]
    BACKSPACE = [Curses::Key::BACKSPACE, 127]

    ##
    # @return [String]
    attr_reader :buffer

    ##
    # @param [LLM::Agent] agent
    # @return [LLM::Repl::Input]
    def initialize(agent, options = {})
      @agent = agent
      @provider = agent.llm.name
      @buffer = +""
      @cursor = 0
      @scroll = 0
      @height = options.fetch(:height, 3)
    end

    ##
    # @param [LLM::Repl::Window] window
    # @param [Object] char
    # @return [Symbol, nil]
    def on_char(window, char)
      if CTRL[:D] == char
        delete
        :ctrl_d
      elsif CTRL[:A] == char
        move_start
        :ctrl_a
      elsif CTRL[:E] == char
        move_end
        :ctrl_e
      elsif CTRL[:F] == char
        move_forward
        :ctrl_f
      elsif CTRL[:Y] == char
        restore
        :ctrl_y
      elsif CTRL[:K] == char
        kill
        :ctrl_k
      elsif char == LEFT
        move_left
        :left
      elsif char == RIGHT
        move_right
        :right
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
    # @return [Integer]
    def height
      @height
    end

    ##
    # Returns the visible lines of the input buffer,
    # wrapped at the given column width. The viewport
    # follows the cursor so the cursor line is always
    # visible.
    # @param [Integer] cols
    # @return [Array<String>]
    def lines(cols)
      sync_scroll(cols)
      text = to_s
      chunks = text.chars.each_slice(cols).map(&:join)
      chunks = [""] if chunks.empty?
      chunks[@scroll, height] || []
    end

    ##
    # Returns the cursor position as [line, column] within
    # the visible viewport.
    # @param [Integer] cols
    # @return [Array(Integer, Integer)]
    def cursor_pos(cols)
      sync_scroll(cols)
      [(cursor / cols) - @scroll, cursor % cols]
    end

    ##
    # @return [void]
    def move_start
      @cursor = 0
    end

    ##
    # @return [void]
    def move_end
      @cursor = [0, @buffer.size].max
    end

    ##
    # @return [void]
    def move_left
      @cursor = [@cursor - 1, 0].max
    end

    ##
    # @return [void]
    def move_right
      @cursor = [@cursor + 1, @buffer.size].min
    end

    ##
    # @return [void]
    def move_forward
      @cursor = [0, @cursor + 1].max
    end

    ##
    # @return [void]
    def kill
      @copy = @buffer.slice(@cursor, @buffer.size)
      @buffer[@cursor, @buffer.size] = ""
      @cursor = @buffer.size
    end

    ##
    # @return [void]
    def delete
      @buffer[@cursor] = ""
      @cursor = [0, @cursor].max
    end

    ##
    # @return [void]
    def restore
      return unless @copy
      @buffer.insert(@cursor, @copy)
      @cursor += @copy.size
    end

    ##
    # @return [String]
    def take
      @buffer.dup.tap do
        @buffer.clear
        @cursor = 0
        @scroll = 0
      end
    end

    private

    ##
    # Adjusts @scroll so the cursor line is visible within
    # the viewport.
    def sync_scroll(cols)
      total_lines = [1, (to_s.length.to_f / cols).ceil].max
      cursor_line = cursor / cols
      if cursor_line < @scroll
        @scroll = cursor_line
      elsif cursor_line >= (@scroll + height)
        @scroll = (cursor_line - height) + 1
      end
      @scroll = [[@scroll, (total_lines - height)].min, 0].max
    end

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
