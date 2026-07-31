#!/usr/bin/env ruby

require "llm"
require "json"
require "fileutils"
require "securerandom"

##
# utils

def keys
  @keys ||= Dir[File.join(__dir__, "..", "lib", "llm", "providers", "*")]
    .select { File.file?(_1) }
    .map { File.basename(_1, ".rb") }
    .sort_by { _1 == "deepseek" ? 0 : 1 }
    .map { "#{_1.upcase}_API_KEY" } - ["BEDROCK_API_KEY"]
end

def help
  prog = File.basename($PROGRAM_NAME)
  warn ""
  warn "Usage: #{prog} [options]"
  warn ""
  warn "Options:"
  warn "  -p PROVIDER    Choose a provider"
  warn "  -t             Temporary session that doesn't persist to disk"
  warn "  -h             Show this help"
  warn ""
  warn "Examples:"
  warn "  #{prog}                     # auto-detect provider from $PROVIDER_API_KEY"
  warn "  #{prog} -p openai           # use OpenAI"
  warn "  #{prog} -h                  # this help"
  warn ""
end

def loaderror(ex)
  gem, = ex.message.split(" is an optional runtime dependency")
  warn ""
  warn "  ── llm.rb ──────────────────────────────────────────────"
  warn ""
  warn "  ✖  Missing dependency: #{gem}"
  warn ""
  warn "     The repl needs this gem, but it's not installed."
  warn ""
  warn "     Fix:  gem install #{gem}"
  warn "     Or:   bundle add #{gem}"
  warn ""
  warn "     Tip:  If you don't need the repl, you can use the"
  warn "           library directly with:  require \"llm\""
  warn ""
  warn "  ───────────────────────────────────────────────────────"
  warn ""
end

##
# main

def main(argv)
  ##
  # Make sure the dependencies are satisified first
  begin
    require "llm/tools"
    require "llm/repl"
  rescue LLM::LoadError => ex
    loaderror(ex)
    exit 1
  end

  ##
  # C-Style option parser
  # No external dep
  while option = argv.shift
    case option
    when '-h'
      help
      exit 0
    when '-t'
      temp = true
    when '-p'
      provider = argv.shift
      if provider.nil?
        warn "llm.rb: -p switch requires an argument"
        help
        exit 1
      end
    else
      warn "llm.rb: unknown option #{option}"
      help
      exit 1
    end
  end

  ##
  # No provider has been given.
  # Try to infer one.
  if provider.nil?
    key = keys.find { ENV[_1] }
    if key.nil?
      warn "llm.rb: provide a provider with the -p switch"
      exit 1
    else
      provider, = key.split("_")
    end
  end
  provider = provider.downcase

  ##
  # Setup the filesystem where <provider>.json maps
  # the current working directory to a session file,
  # and where the session file is stored in
  # `~/.llm.rb/<provider>/<uuid>.json`.
  # This can be skipped with the `-t` option.
  if temp.nil?
    home   = File.join(Dir.home, ".llm.rb")
    file   = File.join(home, "#{provider}.json")
    parent = File.join(home, provider)

    FileUtils.mkdir_p(parent)
    FileUtils.touch(file)

    if File.size(file).zero?
      data = LLM::Object.from({})
      File.binwrite file, JSON.pretty_generate(data)
    else
      data = LLM::Object.from JSON.parse(File.read(file))
    end
    data[Dir.getwd] ||= File.join(parent, "#{SecureRandom.uuid}.json")
  end

  ##
  # We're ready to start the REPL
  # This should always succeed unless -p gave garbage
  if LLM.respond_to?(provider)
    key ||= "#{provider.upcase}_API_KEY"
    if ENV[key].nil? || ENV[key].to_s.empty?
      warn "llm.rb: set #{key} to use #{provider}"
      exit 1
    end
    llm   = LLM.method(provider).call(key: ENV[key])
    path  = temp ? nil : data[Dir.getwd]
    agent = LLM::Agent.new(llm, path:, tools: LLM::Tool.subclasses)
    agent.repl
  else
    warn "llm.rb: #{provider} was not recognized"
    exit 1
  end
end
main(ARGV)
