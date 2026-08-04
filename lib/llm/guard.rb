# frozen_string_literal: true

module LLM
  ##
  # {LLM::Guard LLM::Guard} is the superclass for context-level
  # supervisors in llm.rb.
  #
  # A guard is bound to a context and decides whether pending tool work
  # should be blocked before the agent keeps looping. Each subclass
  # implements {#call} and returns a warning string when execution should
  # be blocked, or `nil` when it should continue. The built-in
  # implementation is {LLM::Guard::Loop LLM::Guard::Loop}, which detects
  # repeated tool-call patterns. {LLM::Guard::Null LLM::Guard::Null} is a
  # no-op and the default.
  #
  # {LLM::Context LLM::Context} uses a guard's warning to return in-band
  # {LLM::GuardError LLM::GuardError} tool errors, and
  # {LLM::Agent LLM::Agent} enables {LLM::Guard::Loop LLM::Guard::Loop}
  # by default through its wrapped context.
  class Guard
    require_relative "guard/null"
    require_relative "guard/loop"

    ##
    # @return [LLM::Context]
    attr_reader :ctx

    ##
    # @param ctx [LLM::Context, LLM::Agent]
    # @return [LLM::Guard]
    def initialize(ctx)
      @ctx = LLM::Agent === ctx ? ctx.instance_variable_get(:@ctx) : ctx
    end

    ##
    # @abstract
    # @param opts [Hash] Per-call options
    # @return [String, nil]
    #  A warning string when pending tool work should be blocked,
    #  or nil when execution should continue.
    def call(**opts)
      raise NotImplementedError
    end

    private

    ##
    # @return [LLM::Stream]
    def stream
      @ctx.params[:stream]
    end

    ##
    # @return [LLM::Buffer]
    def messages
      @ctx.messages
    end
  end
end
