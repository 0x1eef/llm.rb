# frozen_string_literal: true

class LLM::OpenAI
  ##
  # The {LLM::OpenAI::Audio LLM::OpenAI::Audio} class provides an audio
  # object for interacting with [OpenAI's audio API](https://platform.openai.com/docs/api-reference/audio/createSpeech).
  # @example
  #   llm = LLM.openai(ENV["KEY"])
  #   res = llm.audio.create_speech(input: "A dog on a rocket to the moon")
  #   IO.copy_stream res.audio, "rocket.mp3"
  class Audio
    ##
    # Returns a new Audio object
    # @param provider [LLM::Provider]
    # @return [LLM::OpenAI::Responses]
    def initialize(provider)
      @provider = provider
    end

    ##
    # Create an audio track
    # @example
    #   llm = LLM.openai(ENV["KEY"])
    #   res = llm.images.create_speech(input: "A dog on a rocket to the moon")
    #   File.binwrite("rocket.mp3", res.audio.string)
    # @see https://platform.openai.com/docs/api-reference/audio/createSpeech OpenAI docs
    # @param [String] input The text input
    # @param [String] voice The voice to use
    # @param [String] model The model to use
    # @param [String] response_format The response format
    # @param [Hash] params Other parameters (see OpenAI docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response::Audio]
    def create_speech(input:, voice: "alloy", model: "gpt-4o-mini-tts", response_format: "mp3", **params)
      req = Net::HTTP::Post.new("/v1/audio/speech", headers)
      req.body = JSON.dump({input:, voice:, model:, response_format:}.merge!(params))
      io = StringIO.new("".b)
      res = execute(request: req) { _1.read_body { |chunk| io << chunk } }
      LLM::Response::Audio.new(res).tap { _1.audio = io }
    end

    ##
    # Create an audio transcription
    # @example
    #   llm = LLM.openai(ENV["KEY"])
    #   res = llm.audio.create_transcription(file: "/audio/rocket.mp3")
    #   res.text # => "A dog on a rocket to the moon"
    # @see https://platform.openai.com/docs/api-reference/audio/createTranscription OpenAI docs
    # @param [String, LLM::File] file The input audio
    # @param [String] model The model to use
    # @param [Hash] params Other parameters (see OpenAI docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response::AudioTranscription]
    def create_transcription(file:, model: "whisper-1", **params)
      multi = LLM::Multipart.new(params.merge!(file: LLM.File(file), model:))
      req = Net::HTTP::Post.new("/v1/audio/transcriptions", headers)
      req["content-type"] = multi.content_type
      set_body_stream(req, multi.body)
      res = execute(request: req)
      LLM::Response::AudioTranscription.new(res).tap { _1.text = _1.body["text"] }
    end

    ##
    # Create an audio translation (in English)
    # @example
    #   # Arabic => English
    #   llm = LLM.openai(ENV["KEY"])
    #   res = llm.audio.create_translation(file: "/audio/bismillah.mp3")
    #   res.text # => "In the name of Allah, the Beneficent, the Merciful."
    # @see https://platform.openai.com/docs/api-reference/audio/createTranslation OpenAI docs
    # @param [LLM::File] file The input audio
    # @param [String] model The model to use
    # @param [Hash] params Other parameters (see OpenAI docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response::AudioTranslation]
    def create_translation(file:, model: "whisper-1", **params)
      multi = LLM::Multipart.new(params.merge!(file: LLM.File(file), model:))
      req = Net::HTTP::Post.new("/v1/audio/translations", headers)
      req["content-type"] = multi.content_type
      set_body_stream(req, multi.body)
      res = execute(request: req)
      LLM::Response::AudioTranslation.new(res).tap { _1.text = _1.body["text"] }
    end

    private

    [:headers, :execute, :set_body_stream].each do |m|
      define_method(m) { |*args, **kwargs, &b| @provider.send(m, *args, **kwargs, &b) }
    end
  end
end
