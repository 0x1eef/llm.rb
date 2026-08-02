# frozen_string_literal: true

class LLM::Repl
  ##
  # The {LLM::Repl::Input LLM::Repl::Input} class manages
  # the editable input line shown at the bottom of the REPL.
  # @api private
  class Input
    require_relative "input/row"
    require_relative "input/char"

    CTRL = {
      A: Curses::KEY_CTRL_A,
      E: Curses::KEY_CTRL_E,
      F: Curses::KEY_CTRL_F,
      K: Curses::KEY_CTRL_K,
      Y: Curses::KEY_CTRL_Y,
      D: Curses::KEY_CTRL_D,
      P: Curses::KEY_CTRL_P,
      N: Curses::KEY_CTRL_N
    }

    ##
    # This hash tracks how many times a given key
    # was pressed repeatedly without being
    # interrupted by another key. The previous key
    # is reset to 0 when a different key is pressed.
    REPEATS = {}
    REPEATS.default = 0

    UP        = Curses::Key::UP
    DOWN      = Curses::Key::DOWN
    LEFT      = Curses::Key::LEFT
    RIGHT     = Curses::Key::RIGHT
    PGUP      = Curses::KEY_PPAGE
    PGDOWN    = Curses::KEY_NPAGE

    TAB       = 9
    ESC       = 27
    ENTER     = 10
    BACKSPACE = 127

    ##
    # Threshold in seconds. If characters arrive faster than
    # this, we assume the user is pasting multi-line text.
    # Human typing is ~150–300ms per key, so 50ms reliably
    # distinguishes a paste from manual typing.
    PASTE_THRESHOLD = 0.05

    ##
    # @param [Boolean] value
    # @return [void]
    attr_writer :paste

    ##
    # @param [LLM::Repl] repl
    # @return [LLM::Repl::Input]
    def initialize(repl, options = {})
      @name = repl.name
      @agent = repl.agent
      @provider = @agent.llm.name
      @rows = [Row.new]
      @cursor = [0, 0]
      @scroll = 0
      @height = options.fetch(:height, 3)
      @last_char_at = nil
      @memory = @agent.messages.select(&:user?).map(&:content)
      @walker = Walker.new(@memory)
      @paste = false
    end

    ##
    # @return [String]
    #  The input buffer as an ordinary string.
    def buffer
      text
    end

    ##
    # @param [LLM::Repl::Window] window
    # @param [Object] char
    # @return [Symbol, nil]
    def on_char(window, char, now)
      is_paste = lambda { @last_char_at and (now - @last_char_at) < PASTE_THRESHOLD }
      if char and @char != char
        REPEATS[@char] = 0
      end
      if PGUP == char
        (window.rows - 3).times { window.scroll_up }
        :pageup
      elsif PGDOWN == char
        (window.rows - 3).times { window.scroll_down }
        :pagedown
      elsif TAB == char
        autocomplete
        :tab
      elsif ESC == char
        @agent.cancel!
      elsif CTRL[:P] == char
        set_text(@walker.prev.dup)
        :ctrl_p
      elsif CTRL[:N] == char
        set_text(@walker.next.dup)
        :ctrl_n
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
      elsif BACKSPACE == char
        backspace
        :backspace
      elsif ENTER == char
        if @paste = is_paste.()
          insert("\n")
          :char
        else
          @memory.push(text)
          @walker.cursor = @memory.size
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
      if char
        REPEATS[char] += 1
        @last_char_at = now
        @char = char
      end
    end

    ##
    # @return [String]
    def to_s
      @rows
        .each_with_index
        .map { |row, i| (i.zero? ? prompt : "") + row.to_s }
        .join("\n")
    end

    ##
    # @return [Integer]
    def height
      @height
    end

    ##
    # Returns the visible lines of the input buffer. The viewport
    # follows the cursor so the cursor line is always visible.
    # @return [Array<String>]
    def lines
      scroll!
      visible = @rows[@scroll, height] || []
      visible.each_with_index.map do |row, i|
        (i.zero? && @scroll.zero? ? prompt : "") + row.to_s
      end
    end

    ##
    # Returns the cursor position as [line, column] within
    # the visible viewport.
    # @return [Array(Integer, Integer)]
    def cursor_pos
      scroll!
      row, col = @cursor
      col += prompt.size if row.zero?
      [row - @scroll, col]
    end

    ##
    # @return [void]
    def move_start
      @cursor = [0, 0]
    end

    ##
    # @return [void]
    def move_end
      @cursor = [@rows.size - 1, @rows.last.chars.size]
    end

    ##
    # @return [void]
    def move_left
      row, col = @cursor
      @cursor =
        if col > 0 then [row, col - 1]
        elsif row > 0 then [row - 1, @rows[row - 1].chars.size]
        else [0, 0]
        end
    end

    ##
    # @return [void]
    def move_right
      row, col = @cursor
      @cursor =
        if col < @rows[row].chars.size then [row, col + 1]
        elsif row < @rows.size - 1 then [row + 1, 0]
        else [row, col]
        end
    end

    ##
    # @return [void]
    def move_forward
      move_right
    end

    ##
    # @return [void]
    def autocomplete
      return unless text[0] == "/"
      ##
      # This method implements a simple autocomplete
      # that supports cycling through all known
      # commands. When given tab in quick succession,
      # we cycle to the nearest neighbour for the last
      # full match. However, it's not based on similarity,
      # it's just the next element in the array.
      keys = LLM::Command.registry.keys
      candidates = LLM::Command.complete(text)
      candidate =
        if REPEATS[TAB] >= 1
          keys[keys.index(candidates[0]) + 1] || keys[0]
        else
          candidates[0]
        end
      set_text("/#{candidate}")
    end

    ##
    # @return [void]
    def kill
      row, col = @cursor
      tail = @rows[row].chars[col..].map(&:to_s).join
      tail += @rows[(row + 1)..].map(&:to_s).join("\n")
      @copy = tail
      @rows[row].chars.slice!(col..)
      @rows = @rows[0..row]
      @cursor = [row, col]
    end

    ##
    # @return [void]
    def delete
      row, col = @cursor
      @rows[row].chars.delete_at(col) if col < @rows[row].chars.size
    end

    ##
    # @return [void]
    def restore
      return unless @copy
      row, col = @cursor
      @copy.each_char do |char|
        if char == "\n"
          @rows.insert(row + 1, Row.new(:newline))
          row += 1
          col = 0
        else
          @rows[row].chars.insert(col, Char.new(char))
          col += 1
        end
      end
      @cursor = [row, col]
    end

    ##
    # @return [String]
    def take
      text.tap do
        @rows = [Row.new]
        @cursor = [0, 0]
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
      total_lines ||= @rows.size
      cursor_row = @cursor[0]
      if cursor_row < @scroll
        @scroll = cursor_row
      elsif cursor_row >= (@scroll + height)
        @scroll = (cursor_row - height) + 1
      end
      @scroll = [[@scroll, (total_lines - height)].min, 0].max
    end

    def prompt
      "#{@provider}(#{@name})> "
    end

    ##
    # Returns the line the cursor is on, including the prompt.
    # @return [String]
    def current_line
      row = @cursor[0]
      (row.zero? ? prompt : "") + @rows[row].to_s
    end

    ##
    # Inserts a character at the cursor, wrapping the current row at
    # the terminal width by starting a new row. A word that would be
    # cut in half is moved whole onto the new row.
    # @param [String] char
    # @return [void]
    def insert(char)
      row, col = @cursor
      if char == "\n"
        @rows.insert(row + 1, Row.new(:newline))
        @cursor = [row + 1, 0]
      elsif current_line.size >= Curses.cols
        if char == " "
          @rows.insert(row + 1, Row.new(:space))
          @cursor = [row + 1, 0]
        elsif (index = current_line.rindex(" "))
          offset = row.zero? ? prompt.size : 0
          split = index - offset
          tail = @rows[row].chars.slice!((split + 1)..) || []
          @rows[row].chars.delete_at(split)
          @rows.insert(row + 1, Row.new(:space))
          @rows[row + 1].chars.concat(tail)
          @rows[row + 1].chars << Char.new(char)
          @cursor = [row + 1, @rows[row + 1].chars.size]
        else
          @rows.insert(row + 1, Row.new(:space))
          @rows[row + 1].chars << Char.new(char)
          @cursor = [row + 1, 1]
        end
      else
        @rows[row].chars.insert(col, Char.new(char))
        @cursor = [row, col + char.length]
      end
      scroll!
    end

    ##
    # @return [void]
    def backspace
      row, col = @cursor
      if col > 0
        @rows[row].chars.delete_at(col - 1)
        @cursor = [row, col - 1]
      elsif row > 0
        prev = @rows[row - 1]
        prev.chars.concat(@rows[row].chars)
        @rows.delete_at(row)
        @cursor = [row - 1, prev.chars.size]
      end
    end

    ##
    # Flattens the rows into a single string. Each row joins the one
    # before it using its own `break_type`: a row started by an
    # auto-wrap joins with a space, a row started by a real newline
    # joins with a newline.
    # @return [String]
    def text
      out = +""
      @rows.each_with_index do |row, i|
        out << row.to_s
        nxt = @rows[i + 1]
        if nxt
          out << (nxt.break_type == :newline ? "\n" : " ")
        end
      end
      out
    end

    ##
    # Replaces the input with the given string, splitting it into rows.
    # @param [String] string
    # @return [void]
    def set_text(string)
      @rows = []
      first = true
      string.each_line do |line|
        row = Row.new(first ? nil : :newline)
        line.chomp!
        line.each_char { |c| row.chars << Char.new(c) }
        @rows << row
        first = false
      end
      @rows = [Row.new] if @rows.empty?
      @cursor = [@rows.size - 1, @rows.last.chars.size]
    end
  end
end
