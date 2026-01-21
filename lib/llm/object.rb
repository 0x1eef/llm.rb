# frozen_string_literal: true

##
# The {LLM::Object LLM::Object} class encapsulates a Hash object. It is
# similar in spirit to OpenStruct, and it was introduced after OpenStruct
# became a bundled gem rather than a default gem in Ruby 3.5.
class LLM::Object < BasicObject
  require_relative "object/builder"
  require_relative "object/kernel"

  extend Builder
  include Kernel
  include ::Enumerable
  defined?(::PP) ? include(::PP::ObjectMixin) : nil

  ##
  # @param [Hash] h
  # @return [LLM::Object]
  def initialize(h = {})
    @h = h || {}
  end

  ##
  # Yields a key|value pair to a block.
  # @yieldparam [Symbol] k
  # @yieldparam [Object] v
  # @return [void]
  def each(&)
    @h.each(&)
  end

  ##
  # @param [Symbol, #to_sym] k
  # @return [Object]
  def [](k)
    @h[key(k)]
  end

  ##
  # @param [Symbol, #to_sym] k
  # @param [Object] v
  # @return [void]
  def []=(k, v)
    @h[k.to_s] = v
  end

  ##
  # @return [String]
  def to_json(...)
    to_h.to_json(...)
  end

  ##
  # @return [Boolean]
  def empty?
    @h.empty?
  end

  ##
  # @return [Hash]
  def to_h
    @h.transform_keys(&:to_sym)
  end
  alias_method :to_hash, :to_h

  ##
  # @return [Object, nil]
  def dig(...)
    to_h.dig(...)
  end

  ##
  # @return [Hash]
  def slice(...)
    to_h.slice(...)
  end

  private

  def method_missing(m, *args, &b)
    if m.to_s.end_with?("=")
      self[m[0..-2]] = args.first
    elsif k = key(m)
      @h[k]
    else
      nil
    end
  end

  def key(k)
    if @h.key?(k.to_s)
      k.to_s
    elsif @h.key?(k.to_sym)
      k.to_sym
    else
      nil
    end
  end
end
