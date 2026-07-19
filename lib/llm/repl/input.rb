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
    TAB       = 9
    ESC       = 27
    ENTER     = [Curses::Key::ENTER, 10, 13]
    BACKSPACE = [Curses::Key::BACKSPACE, 127]

    ##
    # Threshold in seconds. If characters arrive faster than
    # this, we assume the user is pasting multi-line text.
    # Human typing is ~150–300ms per key, so 50ms reliably
    # distinguishes a paste from manual typing.
    PASTE_THRESHOLD = 0.05

    ##
    # @return [String]
    attr_reader :buffer

    ##
    # @param [Boolean] bool
    # @return [void]
    attr_writer :paste

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
      @last_char_at = nil
      @paste = false
    end

    ##
    # @param [LLM::Repl::Window] window
    # @param [Object] char
    # @return [Symbol, nil]
    def on_char(window, char, now)
      is_paste = lambda { @last_char_at and (now - @last_char_at) < PASTE_THRESHOLD }
      if TAB == char
        autocomplete
        :tab
      elsif ESC == char
        @agent.cancel!
      elsif CTRL[:D] == char
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
        if @paste = is_paste.()
          insert("\n")
          :char
        else
          :submit
        end
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
    ensure
      @last_char_at = now if char
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
    # split by newlines. The viewport follows the cursor
    # so the cursor line is always visible.
    # @return [Array<String>]
    def lines
      scroll!
      chunks = to_s.split("\n", -1)
      chunks[@scroll, height] || []
    end

    ##
    # Returns the cursor position as [line, column] within
    # the visible viewport.
    # @return [Array(Integer, Integer)]
    def cursor_pos
      scroll!
      before = to_s[0...cursor]
      line  = before.count("\n")
      col   = cursor - (before.rindex("\n") || -1) - 1
      [line - @scroll, col]
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
    def autocomplete
      return unless @buffer[0] == "/"
      ##
      # For now this is just a very simple
      # autocomplete. It doesn't support cycles
      # and even though its limited at the moment
      # it is hoped to be useful.
      candidates = LLM::Repl::Command.complete(@buffer)
      if candidates.any?
        @buffer = "/#{candidates[0]}"
        @cursor = @buffer.size
      end
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

    ##
    # @return [Boolean]
    def paste?
      @paste
    end

    private

    ##
    # Adjusts @scroll so the cursor line is visible within
    # the viewport.
    def scroll!(total_lines = nil)
      total_lines ||= to_s.split("\n", -1).size
      cursor_line = to_s[0...cursor].count("\n")
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
      if lines[-1].size >= Curses.cols
        @buffer.insert(@cursor, "\n")
        @cursor += 1
      end
      @buffer.insert(@cursor, char)
      @cursor += char.length
      scroll!
    end

    def backspace
      return if @cursor <= 0
      @buffer.slice!(@cursor - 1)
      @cursor -= 1
    end
  end
end
