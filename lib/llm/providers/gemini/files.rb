# frozen_string_literal: true

class LLM::Gemini
  ##
  # The {LLM::Gemini::Files LLM::Gemini::Files} class provides a files
  # object for interacting with [Gemini's Files API](https://ai.google.dev/gemini-api/docs/files).
  # The files API allows a client to reference media files in prompts
  # where they can be referenced by their URL.
  #
  # The files API is intended to preserve bandwidth and latency,
  # especially for large files but it can be helpful for smaller files
  # as well because it does not require the client to include a file
  # in the prompt over and over again (which could be the case in a
  # multi-turn conversation).
  #
  # @example
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.gemini(ENV["KEY"])
  #   bot = LLM::Chat.new(llm).lazy
  #   file = llm.files.create file: LLM::File("/audio/haiku.mp3")
  #   bot.chat(file)
  #   bot.chat("Describe the audio file I sent to you")
  #   bot.chat("The audio file is the first message I sent to you.")
  #   bot.messages.select(&:assistant?).each { print "[#{_1.role}]", _1.content, "\n" }
  # @example
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.gemini(ENV["KEY"])
  #   bot = LLM::Chat.new(llm).lazy
  #   file = llm.files.create file: LLM::File("/audio/haiku.mp3")
  #   bot.chat(["Describe the audio file I sent to you", file])
  #   bot.messages.select(&:assistant?).each { print "[#{_1.role}]", _1.content, "\n" }
  class Files
    ##
    # Returns a new Files object
    # @param provider [LLM::Provider]
    # @return [LLM::Gemini::Files]
    def initialize(provider)
      @provider = provider
    end

    ##
    # List all files
    # @example
    #   llm = LLM.gemini(ENV["KEY"])
    #   res = llm.files.all
    #   res.each do |file|
    #     print "name: ", file.name, "\n"
    #   end
    # @see https://ai.google.dev/gemini-api/docs/files Gemini docs
    # @param [Hash] params Other parameters (see Gemini docs)
    # @raise (see LLM::HTTPClient#request)
    # @return [LLM::Response::FileList]
    def all(**params)
      query = URI.encode_www_form(params.merge!(key: secret))
      req = Net::HTTP::Get.new("/v1beta/files?#{query}", headers)
      res = request(http, req)
      LLM::Response::FileList.new(res).tap { |filelist|
        files = filelist.body["files"]&.map do |file|
          file = file.transform_keys { snakecase(_1) }
          OpenStruct.from_hash(file)
        end || []
        filelist.files = files
      }
    end

    ##
    # Create a file
    # @example
    #   llm = LLM.gemini(ENV["KEY"])
    #   res = llm.files.create file: LLM::File("/audio/haiku.mp3"),
    # @see https://ai.google.dev/gemini-api/docs/files Gemini docs
    # @param [File] file The file
    # @param [Hash] params Other parameters (see Gemini docs)
    # @raise (see LLM::HTTPClient#request)
    # @return [LLM::Response::File]
    def create(file:, **params)
      req = Net::HTTP::Post.new(request_upload_url(file:), {})
      req["content-length"] = file.bytesize
      req["X-Goog-Upload-Offset"] = 0
      req["X-Goog-Upload-Command"] = "upload, finalize"
      file.with_io do |io|
        req.body_stream = io
        res = request(http, req)
        LLM::Response::File.new(res)
      end
    end

    ##
    # Get a file
    # @example
    #   llm = LLM.gemini(ENV["KEY"])
    #   res = llm.files.get(file: "files/1234567890")
    #   print "name: ", res.name, "\n"
    # @see https://ai.google.dev/gemini-api/docs/files Gemini docs
    # @param [#name, String] file The file to get
    # @param [Hash] params Other parameters (see Gemini docs)
    # @raise (see LLM::HTTPClient#request)
    # @return [LLM::Response::File]
    def get(file:, **params)
      file_id = file.respond_to?(:name) ? file.name : file.to_s
      query = URI.encode_www_form(params.merge!(key: secret))
      req = Net::HTTP::Get.new("/v1beta/#{file_id}?#{query}", headers)
      res = request(http, req)
      LLM::Response::File.new(res)
    end

    ##
    # Delete a file
    # @example
    #   llm = LLM.gemini(ENV["KEY"])
    #   res = llm.files.delete(file: "files/1234567890")
    # @see https://ai.google.dev/gemini-api/docs/files Gemini docs
    # @param [#name, String] file The file to delete
    # @param [Hash] params Other parameters (see Gemini docs)
    # @raise (see LLM::HTTPClient#request)
    # @return [LLM::Response::File]
    def delete(file:, **params)
      file_id = file.respond_to?(:name) ? file.name : file.to_s
      query = URI.encode_www_form(params.merge!(key: secret))
      req = Net::HTTP::Delete.new("/v1beta/#{file_id}?#{query}", headers)
      request(http, req)
    end

    ##
    # @raise [NotImplementedError]
    #  This method is not implemented by Gemini
    def download
      raise NotImplementedError
    end

    private

    include LLM::Utils

    def request_upload_url(file:)
      req = Net::HTTP::Post.new("/upload/v1beta/files?key=#{secret}", headers)
      req["X-Goog-Upload-Protocol"] = "resumable"
      req["X-Goog-Upload-Command"] = "start"
      req["X-Goog-Upload-Header-Content-Length"] = file.bytesize
      req["X-Goog-Upload-Header-Content-Type"] = file.mime_type
      req.body = JSON.dump(file: {display_name: File.basename(file.path)})
      res = request(http, req)
      res["x-goog-upload-url"]
    end

    def http
      @provider.instance_variable_get(:@http)
    end

    def secret
      @provider.instance_variable_get(:@secret)
    end

    [:headers, :request].each do |m|
      define_method(m) { |*args, &b| @provider.send(m, *args, &b) }
    end
  end
end
