# frozen_string_literal: true

module Tools
  class CreateImage < LLM::Tool
    name "create-image"
    description "Create a generated image"
    param :prompt, String, "The prompt", required: true

    ##
    # Returns a HTML link for an image
    # @return [Hash]
    def call(prompt:)
      llm = LLM.gemini(key: ENV["GEMINI_SECRET"])
      res = llm.images.create(prompt:)
      IO.copy_stream res.images[0], destination
      { markup: }
    end

    private

    def project_root = File.realpath(File.join(__dir__, "..", ".."))
    def images_dir = File.join(project_root, "public", "g")
    def destination = File.join(images_dir, filename)
    def markup = "<img src='/g/#{filename}' alt='generated image'>"

    def filename
      @filename ||= "#{SecureRandom.hex}.png"
    end
  end
end
