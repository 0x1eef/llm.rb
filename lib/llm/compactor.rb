# frozen_string_literal: true

##
# {LLM::Compactor LLM::Compactor} summarizes older context messages into a
# smaller replacement message when a context grows too large.
#
# This work is directly inspired by the compaction approach developed by
# General Intelligence Systems in
# [Brute](https://github.com/general-intelligence-systems/brute).
#
# The compactor can also use a different model from the main context by
# setting `model:` in the compactor config.
class LLM::Compactor
  DEFAULTS = {
    token_threshold: 100_000,
    message_threshold: 200,
    retention_window: 8,
    model: nil
  }.freeze

  ##
  # @return [Hash]
  attr_reader :config

  ##
  # @param [LLM::Context] ctx
  # @param [Hash] config
  # @option config [Integer] :token_threshold
  # @option config [Integer] :message_threshold
  # @option config [Integer] :retention_window
  # @option config [String, nil] :model
  #  The model to use for the summarization request. Defaults to the current
  #  context model.
  def initialize(ctx, **config)
    @ctx = ctx
    @config = DEFAULTS.merge(config)
  end

  ##
  # Returns true when the context should be compacted
  # @param [Object] prompt
  #  The next prompt or turn input
  # @return [Boolean]
  def compact?(prompt = nil)
    return false if ctx.functions.any? || [*prompt].grep(LLM::Function::Return).any?
    messages = ctx.messages.reject(&:system?)
    return true if messages.size > config[:message_threshold]
    usage = ctx.usage
    return true if usage && (usage.total_tokens || 0) > config[:token_threshold]
    false
  end

  ##
  # Summarize older messages and replace them with a compact summary.
  # @param [Object] prompt
  #  The next prompt or turn input
  # @return [LLM::Message, nil]
  def compact!(prompt = nil)
    messages = ctx.messages.reject(&:system?)
    retention_window = [config[:retention_window], messages.size].min
    return nil unless compact?(prompt) && messages.size > retention_window
    recent = retained_messages
    older = messages[0...(messages.size - recent.size)]
    summary = LLM::Message.new(ctx.llm.user_role, "[Previous conversation summary]\n\n#{summarize(older)}")
    ctx.messages.replace([*ctx.messages.take_while(&:system?), summary, *recent])
    summary
  end

  private

  attr_reader :ctx

  def retained_messages
    messages = ctx.messages.reject(&:system?)
    retention_window = [config[:retention_window], messages.size].min
    start = [messages.size - retention_window, 0].max
    start -= 1 while start > 0 && messages[start].tool_return?
    messages[start..] || []
  end

  def summarize(messages)
    model = config[:model] || ctx.params[:model] || ctx.llm.default_model
    ctx.llm.complete(summary_prompt(messages), model:).content
  end

  def summary_prompt(messages)
    <<~PROMPT
      Summarize this conversation history for context continuity.
      The summary will replace these messages in the context window.

      Focus on:
      - What the user asked for
      - Important facts and decisions
      - Tool calls and outcomes that still matter
      - What should happen next

      Conversation:
      #{serialize(messages)}
    PROMPT
  end

  def serialize(messages)
    messages.map do |message|
      content = case message.content
      when Array then message.content.map(&:inspect).join(", ")
      else message.content.to_s
      end
      "#{message.role}: #{content.empty? ? "(empty)" : content}"
    end.join("\n---\n")
  end
end
