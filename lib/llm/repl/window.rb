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
    # @return [LLM::Repl::Transcript]
    attr_reader :transcript

    ##
    # @return [LLM::Repl::Input]
    attr_reader :input

    ##
    # @param [LLM::Repl::Status] status
    # @param [LLM::Repl::Transcript] transcript
    # @param [LLM::Repl::Input] input
    # @return [LLM::Repl::Window]
    def initialize(status, transcript, input)
      @status = status
      @transcript = transcript
      @input = input
    end

    ##
    # @yield
    # @return [void]
    def open
      Curses.init_screen
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
      draw_status(offset: input.height + 1)
      draw_divider(offset: 5)
      draw_transcript(offset: 0)
      draw_input
      Curses.refresh
    end

    ##
    # @return [Integer]
    def rows
      [Curses.lines - (input.height + 4), 1].max
    end

    ##
    # @return [Object]
    def getch
      Curses.getch
    end

    ##
    # @return [void]
    def scroll_up
      transcript.scroll_up(rows)
    end

    ##
    # @return [void]
    def scroll_down
      transcript.scroll_down
    end

    private

    def draw_status(offset:)
      Curses.setpos(Curses.lines - offset, 0)
      Curses.clrtoeol
      Curses.addstr(status.to_s)
      context = status.context_bar
      Curses.setpos(Curses.lines - offset, [(columns - context.length) / 2, 0].max)
      Curses.addstr(context)
      cost = status.cost.to_s
      Curses.setpos(Curses.lines - offset, [columns - cost.length, 0].max)
      Curses.addstr(cost)
    end

    def draw_divider(offset:)
      Curses.setpos(Curses.lines - offset, 0)
      Curses.clrtoeol
      Curses.addstr("─" * Curses.cols)
    end

    def draw_input
      cols = columns
      rows = input.lines(cols)
      (0...input.height).each do |idx|
        Curses.setpos((Curses.lines - input.height) + idx, 0)
        Curses.clrtoeol
        Curses.addstr(rows[idx]) if idx < rows.length
      end
      line, col = input.cursor_pos(cols)
      Curses.setpos((Curses.lines - input.height) + line, col)
    end

    def draw_transcript(offset:)
      rows = transcript.visible(self.rows)
      rows.each.with_index(offset) do |row, index|
        Curses.setpos(index, 0)
        Curses.clrtoeol
        row.each do |chunk|
          text, attrs = chunk.values_at(:text, :attrs)
          Curses.attron(attrs) if attrs
          Curses.addstr(text)
          Curses.attroff(attrs) if attrs
        end
      end
      last_drawn = offset + rows.size
      (last_drawn...self.rows).each do |line|
        Curses.setpos(line, 0)
        Curses.clrtoeol
      end
    end

    ##
    # @return [Integer]
    def columns
      Curses.cols
    end
  end
end
