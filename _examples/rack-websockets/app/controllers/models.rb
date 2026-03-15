# frozen_string_literal: true

module Controller
  class Models < Base
    ##
    # Returns the chat-capable models for the provider
    # @return [Array]
    def call
      [
        200,
        {"content-type" => "application/json"},
        [llm.models.all.select(&:chat?).map { {id: _1.id, name: _1.name} }.to_json]
      ]
    end
  end
end
