# frozen_string_literal: true

class LLM::OpenAI
  ##
  # The {LLM::OpenAI::VectorStores LLM::OpenAI::VectorStores} class provides
  # an interface for [OpenAI's vector stores API](https://platform.openai.com/docs/api-reference/vector_stores/create).
  #
  # @example
  #  llm = LLM.openai(key: ENV["OPENAI_SECRET"])
  #  files = %w(foo.pdf bar.pdf).map { llm.files.create(file: _1) }
  #  store = llm.vector_stores.create_and_poll(name: "PDF Store", file_ids: files.map(&:id))
  #  print "[-] store is ready", "\n"
  #  chunks = llm.vector_stores.search(vector: store, query: "What is Ruby?")
  #  chunks.each { |chunk| puts chunk }
  class VectorStores
    require_relative "response/enumerable"
    PollError = Class.new(LLM::Error)

    ##
    # @param [LLM::Provider] provider
    #  An OpenAI provider
    def initialize(provider)
      @provider = provider
    end

    ##
    # List all vector stores
    # @param [Hash] params Other parameters (see OpenAI docs)
    # @return [LLM::Response]
    def all(**params)
      query = URI.encode_www_form(params)
      req = Net::HTTP::Get.new("/v1/vector_stores?#{query}", headers)
      res = execute(request: req)
      LLM::Response.new(res).extend(LLM::OpenAI::Response::Enumerable)
    end

    ##
    # Create a vector store
    # @param [String] name The name of the vector store
    # @param [Array<String>] file_ids The IDs of the files to include in the vector store
    # @param [Hash] params Other parameters (see OpenAI docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    # @see https://platform.openai.com/docs/api-reference/vector_stores/create OpenAI docs
    def create(name:, file_ids: [], **params)
      req = Net::HTTP::Post.new("/v1/vector_stores", headers)
      req.body = JSON.dump(params.merge({name:, file_ids:}).compact)
      res = execute(request: req)
      LLM::Response.new(res)
    end

    ##
    # Create a vector store and poll until its status is "completed"
    # @param (see LLM::OpenAI::VectorStores#create)
    # @return (see LLM::OpenAI::VectorStores#poll)
    def create_and_poll(...)
      poll(vector: create(...))
    end

    ##
    # Get a vector store
    # @param [String, #id] vector The ID of the vector store
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    # @see https://platform.openai.com/docs/api-reference/vector_stores/retrieve OpenAI docs
    def get(vector:)
      vector_id = vector.respond_to?(:id) ? vector.id : vector
      req = Net::HTTP::Get.new("/v1/vector_stores/#{vector_id}", headers)
      res = execute(request: req)
      LLM::Response.new(res)
    end

    ##
    # Modify an existing vector store
    # @param [String, #id] vector The ID of the vector store
    # @param [String] name The new name of the vector store
    # @param [Hash] params Other parameters (see OpenAI docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    # @see https://platform.openai.com/docs/api-reference/vector_stores/modify OpenAI docs
    def modify(vector:, name: nil, **params)
      vector_id = vector.respond_to?(:id) ? vector.id : vector
      req = Net::HTTP::Post.new("/v1/vector_stores/#{vector_id}", headers)
      req.body = JSON.dump(params.merge({name:}).compact)
      res = execute(request: req)
      LLM::Response.new(res)
    end

    ##
    # Delete a vector store
    # @param [String, #id] vector The ID of the vector store
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    # @see https://platform.openai.com/docs/api-reference/vector_stores/delete OpenAI docs
    def delete(vector:)
      vector_id = vector.respond_to?(:id) ? vector.id : vector
      req = Net::HTTP::Delete.new("/v1/vector_stores/#{vector_id}", headers)
      res = execute(request: req)
      LLM::Response.new(res)
    end

    ##
    # Search a vector store
    # @param [String, #id] vector The ID of the vector store
    # @param query [String] The query to search for
    # @param params [Hash] Other parameters (see OpenAI docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    # @see https://platform.openai.com/docs/api-reference/vector_stores/search OpenAI docs
    def search(vector:, query:, **params)
      vector_id = vector.respond_to?(:id) ? vector.id : vector
      req = Net::HTTP::Post.new("/v1/vector_stores/#{vector_id}/search", headers)
      req.body = JSON.dump(params.merge({query:}).compact)
      res = execute(request: req)
      LLM::Response.new(res).extend(LLM::OpenAI::Response::Enumerable)
    end

    ##
    # List all files in a vector store
    # @param [String, #id] vector The ID of the vector store
    # @param [Hash] params Other parameters (see OpenAI docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    # @see https://platform.openai.com/docs/api-reference/vector_stores_files/listFiles OpenAI docs
    def all_files(vector:, **params)
      vector_id = vector.respond_to?(:id) ? vector.id : vector
      query = URI.encode_www_form(params)
      req = Net::HTTP::Get.new("/v1/vector_stores/#{vector_id}/files?#{query}", headers)
      res = execute(request: req)
      LLM::Response.new(res).extend(LLM::OpenAI::Response::Enumerable)
    end

    ##
    # Add a file to a vector store
    # @param [String, #id] vector The ID of the vector store
    # @param [String, #id] file The ID of the file to add
    # @param [Hash] attributes Attributes to associate with the file (optional)
    # @param [Hash] params Other parameters (see OpenAI docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    # @see https://platform.openai.com/docs/api-reference/vector_stores_files/createFile OpenAI docs
    def add_file(vector:, file:, attributes: nil, **params)
      vector_id = vector.respond_to?(:id) ? vector.id : vector
      file_id = file.respond_to?(:id) ? file.id : file
      req = Net::HTTP::Post.new("/v1/vector_stores/#{vector_id}/files", headers)
      req.body = JSON.dump(params.merge({file_id:, attributes:}).compact)
      res = execute(request: req)
      LLM::Response.new(res)
    end
    alias_method :create_file, :add_file

    ##
    # Update a file in a vector store
    # @param [String, #id] vector The ID of the vector store
    # @param [String, #id] file The ID of the file to update
    # @param [Hash] attributes Attributes to associate with the file
    # @param [Hash] params Other parameters (see OpenAI docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    # @see https://platform.openai.com/docs/api-reference/vector_stores_files/updateAttributes OpenAI docs
    def update_file(vector:, file:, attributes:, **params)
      vector_id = vector.respond_to?(:id) ? vector.id : vector
      file_id = file.respond_to?(:id) ? file.id : file
      req = Net::HTTP::Post.new("/v1/vector_stores/#{vector_id}/files/#{file_id}", headers)
      req.body = JSON.dump(params.merge({attributes:}).compact)
      res = execute(request: req)
      LLM::Response.new(res)
    end

    ##
    # Get a file from a vector store
    # @param [String, #id] vector The ID of the vector store
    # @param [String, #id] file The ID of the file to retrieve
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    # @see https://platform.openai.com/docs/api-reference/vector_stores_files/getFile OpenAI docs
    def get_file(vector:, file:, **params)
      vector_id = vector.respond_to?(:id) ? vector.id : vector
      file_id = file.respond_to?(:id) ? file.id : file
      query = URI.encode_www_form(params)
      req = Net::HTTP::Get.new("/v1/vector_stores/#{vector_id}/files/#{file_id}?#{query}", headers)
      res = execute(request: req)
      LLM::Response.new(res)
    end

    ##
    # Delete a file from a vector store
    # @param [String, #id] vector The ID of the vector store
    # @param [String, #id] file The ID of the file to delete
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    # @see https://platform.openai.com/docs/api-reference/vector_stores_files/deleteFile OpenAI docs
    def delete_file(vector:, file:)
      vector_id = vector.respond_to?(:id) ? vector.id : vector
      file_id = file.respond_to?(:id) ? file.id : file
      req = Net::HTTP::Delete.new("/v1/vector_stores/#{vector_id}/files/#{file_id}", headers)
      res = execute(request: req)
      LLM::Response.new(res)
    end

    ##
    # Poll a vector store until its status is "completed"
    # @param [String, #id] vector The ID of the vector store
    # @param [Integer] attempts The current number of attempts (default: 0)
    # @param [Integer] max The maximum number of iterations (default: 50)
    # @raise [LLM::PollError] When the maximum number of iterations is reached
    # @return [LLM::Response]
    def poll(vector:, attempts: 0, max: 50)
      if attempts == max
        raise LLM::PollError, "vector store '#{vector.id}' has status '#{vector.status}' after #{max} attempts"
      elsif vector.status == "expired"
        raise LLM::PollError, "vector store '#{vector.id}' has expired"
      elsif vector.status != "completed"
        vector = get(vector:)
        sleep(0.1 * (2**attempts))
        poll(vector:, attempts: attempts + 1, max:)
      else
        vector
      end
    end

    private

    [:headers, :execute, :set_body_stream].each do |m|
      define_method(m) { |*args, **kwargs, &b| @provider.send(m, *args, **kwargs, &b) }
    end
  end
end
