# frozen_string_literal: true

class LLM::Function
  ##
  # The {LLM::Function::Fork::Task} class wraps a fork-backed function call
  # and exchanges control and result messages with the child process.
  class Fork::Task < LLM::Function::Task
    ##
    # @param [LLM::Function] fn
    # @param [Hash] options
    # @option options [LLM::Tracer, nil] :tracer
    # @return [LLM::Function::Fork::Task]
    def initialize(fn, options = {})
      super
      @tracer = options.fetch(:tracer, nil)
      @spawned = false
      @waited = false
    end

    ##
    # @return [LLM::Function::Fork::Task]
    def spawn
      @span = @tracer&.on_tool_start(
        id: @function.id, name: @function.name,
        arguments: @function.arguments, model: @function.model
      )
      @ch = LLM::Object.from(control: xchan(:marshal), result: xchan(:marshal))
      @pid = Kernel.fork { Fork::Job.new(@function, @ch).call }
      @spawned = true
      self
    end

    ##
    # @return [Boolean]
    def alive?
      return false if @waited || !@pid
      result = ::Process.waitpid(@pid, ::Process::WNOHANG)
      @waited = !result.nil?
      !@waited
    rescue Errno::ECHILD
      @waited = true
      false
    end

    ##
    # @return [nil]
    def interrupt!
      return nil if @waited
      @ch.control.write(:interrupt)
      nil
    rescue Errno::ESRCH, IOError
      nil
    end
    alias_method :cancel!, :interrupt!

    ##
    # @return [LLM::Function::Return]
    def wait
      spawn unless @spawned
      kind, data = @ch.result.recv
      raise LLM::Interrupt if kind == :interrupt
      raise ArgumentError, "Unknown fork message: #{kind.inspect}" unless kind == :result
      result = Return.new(data[:id], data[:name], data[:value])
      reap
      @tracer&.on_tool_finish(result:, span: @span)
      result
    ensure
      reap
      [@ch.control, @ch.result].each { _1.close unless _1.closed? }
    end
    alias_method :value, :wait

    ##
    # @return [Class]
    def group_class
      LLM::Function::Fork::Group
    end

    private

    def reap
      return if @waited
      ::Process.waitpid(@pid)
      @waited = true
    rescue Errno::ECHILD
      @waited = true
    end
  end
end
