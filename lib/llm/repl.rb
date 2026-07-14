# frozen_string_literal: true

LLM.require "curses"
LLM.require "kramdown"

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
    require_relative "repl/bar"
    require_relative "repl/stream"
    require_relative "repl/markdown"
    require_relative "repl/command"

    ##
    # @param [LLM::Agent] agent
    # @param [Array<LLM::Tool>] tools
    #  Zero or more tools
    # @param [Array<String>] skills
    #  Zero or more skills
    # @return [LLM::Repl]
    def initialize(agent:, tools:, skills:)
      @agent = agent
      @provider = agent.llm.name
      @status = Status.new(@agent)
      @transcript = Transcript.new
      @input = Input.new(@agent, height: 3)
      @window = Window.new(@status, @transcript, @input)
      @thread = nil
      @queue = Queue.new
      @stream = Stream.new(self, @queue)
      @skills = skills.map do |path|
        ##
        # I'm not sure it would make sense to expose
        # the underlying context or not. In the meantime,
        # this works and meets the expectations of the
        # LLM::Skill class.
        ctx = agent.instance_variable_get(:@ctx)
        LLM::Skill.load(path).to_tool(ctx)
      end
      @tools = [agent.params[:tools], @skills, tools].flatten.compact
    end

    ##
    # @return [void]
    def start
      window.open do
        catch(:exit) do
          loop do
            case input.on_char(window, window.getch)
            when :submit then submit
            when Symbol then window.redraw
            else
              window.redraw
              read!
              sleep 0.01
            end
          end
        end
      end
    end

    ##
    # @param [String] chars
    # @param [Object] attrs
    # @return [void]
    def write(chars, attrs = nil)
      transcript.write(chars, attrs)
      window.redraw
    end

    ##
    # @param [String] chars
    # @return [void]
    def markdown(chars)
      transcript.markdown(chars)
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

    ##
    # This method is called when the user submits their input.
    # It spawns a second thread that maintains a line of
    # communication with a model and the main thread - where
    # the UI runs - remains responsive.
    # @api private
    def submit
      return if thread&.alive?
      text = input.take
      return if text.empty?
      status.text = "thinking"
      write("user: ", Curses::A_BOLD)
      markdown(text)
      write("\nagent: ", Curses::A_BOLD)
      @thread = Thread.new do
        @queue << [:start]
        agent.talk(text, tools:, stream:)
        @queue << [:done]
      rescue => e
        @queue << [:error, e]
      end
    end

    ##
    # This method reads from the queue that is written to
    # by a second thread. The queue is managed or written
    # to by a subclass of {LLM::Stream LLM::Stream}.
    # @api private
    def read!
      loop do
        type, value = @queue.pop(true)
        case type
        when :start
          transcript.start
          stream.empty!
        when :stream
          transcript.markdown(value, method: :replace)
        when :status
          self.status = value
        when :done
          status.text = "idle"
          @thread = nil
          transcript.finish
          write("\n\n")
        when :error
          # Do this better
          status.text = "error"
          transcript.finish
          write("\nerror: #{value.message}\n", Curses::A_BOLD)
          @thread = nil
        end
      end
    rescue ThreadError
    end

    attr_reader :agent, :provider, :stream,
                :status, :transcript, :input,
                :window, :tools, :thread
  end
end
