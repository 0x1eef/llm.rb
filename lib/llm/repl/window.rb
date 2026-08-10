# frozen_string_literal: true

class LLM::Repl
  ##
  # The {LLM::Repl::Window LLM::Repl::Window} class draws the
  # curses screen for the REPL.
  # @api private
  class Window
    ##
    # @return [LLM::Repl::Status]
    attr_reader :status

    ##
    # @return [LLM::Repl::Buffer]
    attr_reader :buffer

    ##
    # @return [LLM::Repl::Input]
    attr_reader :input

    ##
    # @param [LLM::Repl] repl
    #  A read-eval-print loop.
    # @return [LLM::Repl::Window]
    def initialize(repl)
      @repl   = repl
      @status = repl.status
      @buffer = repl.buffer
      @input  = repl.input
    end

    ##
    # @yield
    # @return [void]
    def open
      Curses.init_screen
      Color.enable
      Curses.cbreak
      Curses.noecho
      Curses.stdscr.keypad(true)
      Curses.stdscr.nodelay = true
      yield
    ensure
      Curses.close_screen
    end

    ##
    # @return [void]
    def redraw
      draw_status(offset: input.height + 2)
      draw_meta(offset: input.height + 1)
      draw_divider(offset: 6)
      draw_buffer(offset: 0)
      draw_input
      Curses.refresh
    end

    ##
    # @return [Integer]
    def rows
      [Curses.lines - (input.height + 4), 1].max
    end

    ##
    # @return [Integer]
    def columns
      Curses.cols
    end

    ##
    # @return [Object]
    def getch
      Curses.getch
    end

    ##
    # Drains all available characters from the terminal input
    # buffer without blocking.  Used in place of `Curses.getstr`
    # when the paste flag is set, so that a huge multi-line
    # paste is consumed in a single shot instead of being
    # processed character-by-character.
    # @return [String]
    def read_paste
      chars = +""
      loop do
        ch = Curses.getch
        break unless ch and ch != -1
        chars << ch
      end
      input.paste = false
      chars
    end

    ##
    # @return [void]
    def scroll_up
      buffer.scroll_up(rows)
    end

    ##
    # @return [void]
    def scroll_down
      buffer.scroll_down
    end

    ##
    # @return [void]
    def scroll_to_bottom
      buffer.scroll_to_bottom
    end

    private

    def draw_buffer(offset:)
      rows = buffer.visible(self.rows)
      rows.each.with_index(offset) do |row, index|
        Curses.setpos(index, 0)
        Curses.clrtoeol
        Curses.setpos(index, gutter)
        width = 0
        row.each do |chunk|
          remaining = buffer.width - width
          break if remaining <= 0
          text, attrs = chunk.text.to_s, chunk.attrs
          clipped = text[0, remaining]
          Curses.attron(attrs) if attrs
          Curses.addstr(clipped)
          Curses.attroff(attrs) if attrs
          width += clipped.length
        end
      end
      last_drawn = offset + rows.size
      (last_drawn...self.rows).each do |line|
        Curses.setpos(line, 0)
        Curses.clrtoeol
      end
    end

    def draw_status(offset:)
      Curses.setpos(Curses.lines - offset, 0)
      Curses.clrtoeol
      status.nodes.each { addnode(_1) }
      context = status.context_bar
      Curses.setpos(Curses.lines - offset, [(columns - context.length) / 2, 0].max)
      Curses.addstr(context)
      cost = status.cost.to_s
      Curses.setpos(Curses.lines - offset, [columns - cost.length, 0].max)
      Curses.addstr(cost)
    end

    ##
    # Draws the meta row (model left, cwd right) above the status row.
    # @param [Integer] offset
    # @return [void]
    def draw_meta(offset:)
      Curses.setpos(Curses.lines - offset, 0)
      Curses.clrtoeol
      addnode(status.model, status.model.text[0, columns])
      Curses.setpos(Curses.lines - offset, [columns - status.cwd.size, 0].max)
      addnode(status.cwd, status.cwd.text[0, columns])
    end

    ##
    # Draws a horiztonal line
    # @return [void]
    def draw_divider(offset:)
      Curses.setpos(Curses.lines - offset, 0)
      Curses.clrtoeol
      Curses.addstr("─" * Curses.cols)
    end

    ##
    # Draws the input area
    # @return [void]
    def draw_input
      rows = input.lines
      (0...input.height).each do |idx|
        Curses.setpos((Curses.lines - input.height) + idx, 0)
        Curses.clrtoeol
        Curses.addstr(rows[idx]) if idx < rows.length
      end
      line, col = input.cursor_pos
      Curses.setpos((Curses.lines - input.height) + line, col)
    end

    ##
    # 20% offset that occupies the left margin and
    # helps center {LLM::Repl::Buffer LLM::Repl::Buffer}.
    # @return [Integer]
    def gutter
      (columns * 0.2).floor
    end

    ##
    # Adds a {LLM::Repl::Node} to the Curses window.
    # @param [LLM::Repl::Node] node
    # @param [String] text
    # @return [void]
    def addnode(node, text = node.text)
      Curses.attron(node.attrs) if node.attrs
      Curses.addstr(text)
      Curses.attroff(node.attrs) if node.attrs
    end
  end
end
