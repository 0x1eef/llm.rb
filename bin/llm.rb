#!/usr/bin/env ruby

require "llm"
require "json"
require "fileutils"
require "securerandom"

##
# utils

def providers
  @providers ||= Dir[File.join(__dir__, "..", "lib", "llm", "providers", "*")]
    .select { File.file?(_1) }
    .map { File.basename(_1, ".rb") }
    .sort_by { |provider|
      # <3 DeepSeek
      case provider
      when "deepseek" then -1
      when "ollama", "llamacpp" then 1
      else 0
      end
    }
end

def help
  prog = File.basename($PROGRAM_NAME)
  warn ""
  warn "Usage: #{prog} [options]"
  warn ""
  warn "Options:"
  warn "  -p PROVIDER    Choose a provider"
  warn "  -c STRATEGY    Concurrency strategy for tool calls (eg thread, async, fork)"
  warn "  -n TRANSPORT   HTTP transports - net-http (default), net-http-persistent, and curb"
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
    when '-c'
      concurrency = argv.shift
      if concurrency.nil?
        warn "llm.rb: -c switch requires an argument"
        help
        exit 1
      else
        concurrency = concurrency.to_sym
      end
    when '-n'
      transport = argv.shift
      if transport.nil?
        warn "llm.rb: -n switch requires an argument"
        help
        exit 1
      else
        transport = transport.gsub("-", "_").to_sym
      end
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
    transport ||= :net_http
    llm = providers.filter_map do
      LLM.method(_1).call(transport:)
    rescue ArgumentError
    end.first
    if llm.nil?
      warn "llm.rb: provide a provider with the -p switch"
      exit 1
    end
  else
    begin
      llm = LLM.method(provider).call
    rescue ArgumentError
      warn "llm.rb: set credentials for #{provider}"
      exit 1
    rescue NameError
      warn "llm.rb: unknown provider (#{provider})"
      exit 1
    end
  end

  ##
  # Setup the filesystem where <provider>.json maps
  # the current working directory to a session file,
  # and where the session file is stored in
  # `~/.llm.rb/<provider>/<uuid>.json`.
  # This can be skipped with the `-t` option.
  if temp.nil?
    home   = File.join(Dir.home, ".llm.rb")
    file   = File.join(home, "#{llm.name}.json")
    parent = File.join(home, llm.name.to_s)

    FileUtils.mkdir_p(parent)
    FileUtils.touch(file)

    if File.size(file).zero?
      data = LLM::Object.from({})
      File.binwrite file, JSON.pretty_generate(data)
    else
      data = LLM::Object.from JSON.parse(File.read(file))
    end
    data[Dir.getwd] ||= File.join(parent, "#{SecureRandom.uuid}.json")
    File.binwrite file, JSON.pretty_generate(data)
  end

  ##
  # We're ready to start the REPL
  concurrency ||= :sequential
  path  = temp ? nil : data[Dir.getwd]
  agent = LLM::Agent.new(llm, path:, concurrency:, tools: LLM::Tool.subclasses)
  agent.repl
end
main(ARGV)
