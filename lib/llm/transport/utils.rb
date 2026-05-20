# frozen_string_literal: true

class LLM::Transport
  ##
  # Shared utility methods for HTTP-backed transports.
  #
  # @api private
  module Utils
    extend self
    private

    def resolve_transport(uri, transport, timeout)
      return default_transport(uri, timeout) if transport.nil?
      if Class === transport && transport <= LLM::Transport
        transport.new(
          host: uri.host,
          port: uri.port,
          timeout:,
          ssl: uri.scheme == "https"
        )
      else
        transport
      end
    end

    def default_transport(uri, timeout)
      LLM::Transport::HTTP.new(
        host: uri.host,
        port: uri.port,
        timeout:,
        ssl: uri.scheme == "https"
      )
    end
  end
end
