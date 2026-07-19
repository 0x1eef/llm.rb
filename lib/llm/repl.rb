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

    attr_reader :agent, :provider, :stream,
                :status, :transcript, :input,
                :window, :tools, :thread,
                :name, :path

    ##
    # @param [LLM::Agent] agent
    # @param [String, nil] name
    #  The agent's name (optional)
    # @param [String, nil] path
    #  The path where to maintain runtime state
    # @param [Array<LLM::Tool>] tools
    #  Zero or more tools
    # @param [Array<String>] skills
    #  Zero or more skills
    # @return [LLM::Repl]
    def initialize(agent:, name: nil, tools: [], skills: [], path: nil)
      @path = path
      @name = name || "agent"
      @agent = configure(agent:, path:)
      @provider = agent.llm.name
      @status = Status.new(@agent)
      @transcript = Transcript.new
      @input = Input.new(self, height: 3)
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
            now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            case input.on_char(window, input.paste? ? window.read_paste : window.getch, now)
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

    ##
    # @return [String]
    def thinking_text
      "thinking • Esc to cancel"
    end

    private

    ##
    # @param [LLM::Agent] agent
    #  An agent
    # @param [String] path
    #  A path
    # @raise [LLM::Error]
    #  When given an unusable path
    # @return [LLM::Agent]
    def configure(agent:, path:)
      if path.nil?
        agent
      elsif !File.exist?(path)
        File.write path, "{}"
        agent
      elsif restore?
        agent.restore(path:)
      else
        raise LLM::Error, "I can't use '#{path}' - " \
                          "it should be both readable and writable"
      end
    end

    ##
    # This method is called when the user submits their input.
    # It spawns a second thread that maintains a line of
    # communication with a model and the main thread - where
    # the UI runs - remains responsive.
    # @api private
    def submit
      return if thread&.alive? || (text = input.take).empty?
      case on_text(text)
      in [:command, Command => command, Hash => parameters]
        command.call(**parameters)
      in [:error, String => who, String => text]
        write(who, Curses::A_BOLD)
        write(text)
      in [:input, String => text]
        window.scroll_to_bottom
        status.text = thinking_text
        write("user: ", Curses::A_BOLD)
        markdown(text)
        write("\n#{name}: ", Curses::A_BOLD)
        @thread = Thread.new do
          @queue << [:start]
          agent.talk(text, tools:, stream:)
          agent.save(path:) if save?
          @queue << [:done]
        rescue LLM::Interrupt => e
          @queue << [:cancel, e]
        rescue => e
          @queue << [:error, e]
        end
      end
    end

    ##
    # Receives user input and determines what codepath
    # it should follow - either executing a command,
    # or sending a string to the model.
    # @param [String] text
    # @return [[Symbol, Command|String]]
    def on_text(text)
      command = Command.find_by(input: text)
      if command
        parameters = command.parameters.map { [_1, _2.dup] }.to_h
        args = text.split(" ")[1..].reject(&:empty?)
        reqc = parameters.values.count(&:required?)
        if args.size < reqc
          [:error,
           "command(#{command.name}): ",
           "too few arguments: expected #{reqc} but got #{args.size}\n\n"]
        else
          parameters = parameters.sort_by(&:index).to_h
          kwargs = {}
          parameters.each_value do |parameter|
            if args[parameter.index]
              kwargs[parameter.name] = args[parameter.index]
            end
          end
          [:command, command.new(self), kwargs]
        end
      else
        [:input, text]
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
          write("\n\n")
          transcript.finish
          @thread = nil
        when :cancel
          status.text = "Idle"
          write("\n\n#{name}: ", Curses::A_BOLD)
          write("request cancelled!")
          write("\n\n")
          transcript.finish
          @thread = nil
        when :error
          # Do this better
          status.text = "error"
          write("\nerror: #{value.message}\n", Curses::A_BOLD)
          transcript.finish
          @thread = nil
        end
      end
    rescue ThreadError
    end

    ##
    # @return [Boolean]
    def restore?
      return false if path.nil?
      File.writable?(path)
    end

    ##
    # @return [Boolean]
    def save?
      return false if path.nil?
      File.readable?(path)
    end

    File = ::File
    private_constant :File
  end
end
