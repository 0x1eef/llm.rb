# frozen_string_literal: true

LLM.require "curses"

module LLM
  ##
  # The {LLM::Repl LLM::Repl} class provides a small
  # read-eval-print loop around an instance of
  # {LLM::Agent LLM::Agent}.
  #
  # It can be used to keep talking to an agent after it
  # has been set up or has performed a task. This can be
  # useful when you want to confirm the agent handled the
  # task correctly, or for it to correct course after a
  # mistake was made.
  class Repl
    require_relative "repl/window"
    require_relative "repl/status"
    require_relative "repl/transcript"
    require_relative "repl/input"
    require_relative "repl/stream"

    ##
    # @param [LLM::Agent] agent
    # @param [Array<LLM::Tool>] tools
    # @return [LLM::Repl]
    def initialize(agent, tools)
      @agent = agent
      @provider = agent.llm.name
      @status = Status.new(@provider)
      @transcript = Transcript.new
      @input = Input.new(@provider)
      @window = Window.new(@status, @transcript, @input)
      @stream = Stream.new(self)
      @tools = [agent.params[:tools], tools].flatten.compact
    end

    ##
    # @return [void]
    def start
      window.open do
        loop do
          window.redraw
          text = input.readline(window)
          break if text.nil?
          next if text.empty?
          status.text = "thinking"
          write("user: #{text}\n")
          window.redraw
          write("agent: ")
          agent.talk(text, tools:, stream:)
          status.text = "idle"
          write("\n\n")
        end
      end
    end

    ##
    # @param [String] chars
    # @return [void]
    def write(chars)
      transcript.write(chars)
      window.redraw
    end

    ##
    # @param [String] value
    # @return [void]
    def status=(value)
      status.text = value
      window.redraw
    end

    private

    attr_reader :agent, :provider, :stream,
                :status, :transcript, :input,
                :window, :tools
  end
end
