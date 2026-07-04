# frozen_string_literal: true

module LLM
  ##
  # The JSONAdapter class defines the interface for JSON parsers
  # that can be used by the library when dealing with JSON. The
  # following parsers are supported:
  # * {LLM::JSONAdapter::JSON LLM::JSONAdapter::JSON} (default)
  # * {LLM::JSONAdapter::Oj LLM::JSONAdapter::Oj}
  # * {LLM::JSONAdapter::Yajl LLM::JSONAdapter::Yajl}
  #
  # @example Change parser
  #   LLM.json = LLM::JSONAdapter::Oj
  class JSONAdapter
    ##
    # @return [String]
    #  Returns a JSON string representation of the given object
    def self.dump(*) = raise NotImplementedError

    ##
    # @return [Object]
    #  Returns a Ruby object parsed from the given JSON string
    def self.load(*) = raise NotImplementedError

    ##
    # @return [Exception]
    #  Returns the error raised when parsing fails
    def self.parser_error = [StandardError]
  end

  ##
  # The {LLM::JSONAdapter::JSON LLM::JSONAdapter::JSON} class
  # provides a JSON adapter backed by the standard library
  # JSON module.
  class JSONAdapter::JSON < JSONAdapter
    ##
    # @return (see JSONAdapter#dump)
    def self.dump(obj, state = nil, **options)
      require "json" unless defined?(::JSON)
      if ::JSON::State === state
        ::JSON.generate(normalize(obj), state)
      elsif state
        ::JSON.dump(normalize(obj), state, **options)
      else
        ::JSON.dump(normalize(obj), **options)
      end
    end

    ##
    # @return (see JSONAdapter#load)
    def self.load(string, ...)
      require "json" unless defined?(::JSON)
      ::JSON.parse(string, ...)
    end

    ##
    # @return (see JSONAdapter#parser_error)
    def self.parser_error
      require "json" unless defined?(::JSON)
      [::JSON::ParserError]
    end

    ##
    # JSON 3.0 compat
    # Walks `obj` and encodes every string that is
    # found into a UTF-8 compatible string.
    def self.normalize(obj)
      case obj
      when String then normalize_string(obj)
      when Array then obj.map { normalize(_1) }
      when Hash then obj.map { [_1, normalize(_2)] }.to_h
      when LLM::Object then obj.map { [_1, normalize(_2)] }.to_h
      else obj
      end
    end
    private_class_method :normalize

    ##
    # JSON 3.0 compat
    # Normalizes a string as a UTF-8 encoded string
    # that's compatible with the JSON spec.
    def self.normalize_string(str)
      return str if str.encoding == Encoding::UTF_8
      str = (+str).force_encoding("UTF-8")
      str.valid_encoding? ? str : str.scrub
    end
    private_class_method :normalize_string
  end

  ##
  # The {LLM::JSONAdapter::Oj LLM::JSONAdapter::Oj} class
  # provides a JSON adapter backed by the Oj gem.
  class JSONAdapter::Oj < JSONAdapter
    ##
    # @return (see JSONAdapter#dump)
    def self.dump(obj, options = {})
      require "oj" unless defined?(::Oj)
      ::Oj.dump(obj, options.merge(mode: :compat))
    end

    ##
    # @return (see JSONAdapter#load)
    def self.load(string, options = {})
      require "oj" unless defined?(::Oj)
      ::Oj.load(string, options.merge(mode: :compat, symbol_keys: false, symbolize_names: false))
    end

    ##
    # @return (see JSONAdapter#parser_error)
    def self.parser_error
      require "oj" unless defined?(::Oj)
      [::Oj::ParseError, ::EncodingError]
    end
  end

  ##
  # The {LLM::JSONAdapter::Yajl LLM::JSONAdapter::Yajl} class
  # provides a JSON adapter backed by the Yajl gem.
  class JSONAdapter::Yajl < JSONAdapter
    ##
    # @return (see JSONAdapter#dump)
    def self.dump(obj, ...)
      require "yajl" unless defined?(::Yajl)
      ::Yajl::Encoder.encode(obj, ...)
    end

    ##
    # @return (see JSONAdapter#load)
    def self.load(string, ...)
      require "yajl" unless defined?(::Yajl)
      ::Yajl::Parser.parse(string, ...)
    end

    ##
    # @return (see JSONAdapter#parser_error)
    def self.parser_error
      require "yajl" unless defined?(::Yajl)
      [::Yajl::ParseError]
    end
  end
end
