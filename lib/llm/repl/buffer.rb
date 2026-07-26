# frozen_string_literal: true

class LLM::Repl
  ##
  # This class maintains conversation state that includes
  # the conversation itself, and metadata associated with
  # the conversation.
  #
  # Internally it maintains an array where each element
  # represents a row, and each element in a row is a Hash
  # that describes a piece of text and any styles that might
  # be applied to it by the UI thread.
  #
  # It also maintains a cursor that tracks the active row
  # by its index number. The streaming path reuses a single
  # row by overwriting its contents repeatedly.
  class Buffer
    ##
    # @param [LLM::Repl] repl
    #  An instance of {LLM::Repl LLM::Repl}.
    # @return [LLM::Repl::Buffer]
    def initialize(repl)
      @repl = repl
      @rows = [[]]
      @cursor = nil
      @snapshot = nil
      @offset = 0
    end

    ##
    # @param [String, Array] chars
    # @param [Object] attrs
    # @param [Symbol] method
    # @return [void]
    def write(chars, attrs = nil, method: :append)
      case chars
      when Array then chunks = chars
      else chunks = [{text: chars.to_s, attrs:}.compact]
      end
      self.method(method).call(chunks)
    end

    ##
    # @param [String] user
    # @param [String, Array] content
    # @param [Symbol] method
    # @return [void]
    def write_message(user, content, method: :append)
      chunks = [{text: "#{user}: ", attrs: Curses::A_BOLD}]
      case content
      when Array then chunks.concat(content)
      else chunks.push({text: content})
      end
      chunks.push({text: "\n"})
      write(chunks, method:)
    end

    ##
    # Open the buffer.
    # @return [void]
    def open
      @cursor = @rows.size - 1
      @snapshot = @rows.map(&:dup)
    end

    ##
    # Close the buffer.
    # @return [void]
    def close
      @cursor = nil
      @snapshot = nil
    end

    ##
    # @return [void]
    def scroll_up(height)
      max = [rows.size - height, 0].max
      @offset = [@offset + 1, max].min
    end

    ##
    # @return [void]
    def scroll_down
      @offset = [@offset - 1, 0].max
    end

    ##
    # @return [void]
    def scroll_to_bottom
      @offset = 0
    end

    ##
    # @param [Integer] height
    # @return [Array<String>]
    def visible(height)
      all = rows
      last = all.size - 1 - @offset
      first = [last - height + 1, 0].max
      all[first..last] || []
    end

    private

    ##
    # @return [LLM::Repl]
    attr_reader :repl

    ##
    # Appends a new row
    # @param [Array<{text: String, attrs?: Integer}>] chunks
    #  One or more chunks.
    # @return [void]
    def append(chunks)
      chunks.each { wrap(_1, @rows) }
    end

    ##
    # Replaces the content of the active row
    # @param [Array<{text: String, attrs?: Integer}>] chunks
    #  One or more chunks.
    # @return [void]
    def replace(chunks)
      @rows = @snapshot.map(&:dup)
      chunks.each { wrap(_1, @rows) }
    end

    ##
    # Given a chunk this method wraps text at
    # around 80 columns: a new row starts when
    # the current character is " " and the sum
    # of all characters in that row is greater
    # than 80 columns.
    def wrap(chunk, rows)
      attrs = chunk[:attrs]
      chunk[:text].to_s.each_char do |char|
        if char == "\n"
          rows << []
        elsif char == " " and sum(rows.last) >= repl.width
          rows << []
        else
          rows.last << {text: char, attrs:}.compact
        end
      end
    end

    ##
    # @api private
    def rows
      @rows.dup.tap do |rows|
        ##
        # Discard empty rows that would otherwise
        # be rendered as newlines by the UI thread.
        # It's not the most elegant way to deal with
        # this and we probably shouldn't allow it to
        # happen in the first place.
        while rows.size > 1 and rows.last.empty?
          rows.pop
        end
      end
    end

    ##
    # @api private
    def sum(row)
      row.sum { _1[:text].to_s.length }
    end
  end
end
