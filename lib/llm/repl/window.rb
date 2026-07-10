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
      Curses.clear
      draw_status
      draw_transcript
      draw_input
      Curses.refresh
    end

    ##
    # @return [Integer]
    def rows
      [Curses.lines - 3, 1].max
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

    def draw_status
      Curses.setpos(0, 0)
      Curses.addstr(status.to_s)
      provider = status.provider.to_s
      Curses.setpos(0, [columns - provider.length, 0].max)
      Curses.addstr(provider)
    end

    def draw_transcript
      rows = transcript.visible(self.rows)
      rows.each_with_index do |row, index|
        Curses.setpos(index + 2, 0)
        row.each do |col|
          char, attrs = col.values_at(:char, :attrs)
          Curses.attron(attrs) if attrs
          Curses.addstr(char)
          Curses.attroff(attrs) if attrs
        end
        Curses.addstr("\n")
      end
    end

    def draw_input
      Curses.setpos(Curses.lines - 1, 0)
      Curses.clrtoeol
      Curses.addstr(input.to_s)
    end

    def columns
      Curses.cols
    end
  end
end
