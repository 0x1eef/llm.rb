# frozen_string_literal: true

require "bundler/setup"
require "bundler/gem_tasks"
require "rspec/core/rake_task"

cassettes = File.join(__dir__, "spec", "fixtures", "cassettes")
remotes = %w[openai google anthropic deepseek]
locals  = %w[ollama llamacpp]
bundler = ENV["bundler"] || "bundle"

desc "Run linter"
task :rubocop do
  sh "#{bundler} exec rubocop"
end

namespace :spec do
  namespace :remote do
    desc "Clear remote cassette cache"
    task :clear do
      remotes.each { rm_rf File.join(cassettes, _1) }
    end
  end

  desc "Run remote tests"
  task :remote do
    paths = ["spec/readme_spec.rb", "spec/{#{remotes.join(",")}}/**/*.rb"]
    specs = Dir[*paths].shuffle
    sh "#{bundler} exec rspec #{specs.join(' ')}"
  end

  namespace :local do
    desc "Clear local cassette cache"
    task :clear do
      locals.each { rm_rf File.join(cassettes, _1) }
    end
  end
end

desc "Run all tests"
task :spec do
  sh "#{bundler} exec rspec spec"
end

desc "Start a console with all providers loaded"
task :console do
  require "llm"
  require "dotenv"
  Dotenv.load
  openai = LLM.openai(key: ENV["OPENAI_SECRET"])
  google = LLM.google(key: ENV["GOOGLE_SECRET"])
  anthropic = LLM.anthropic(key: ENV["ANTHROPIC_SECRET"])
  deepseek = LLM.deepseek(key: ENV["DEEPSEEK_SECRET"])
  xai = LLM.xai(key: ENV["XAI_SECRET"])
  binding.irb
end

desc "start a repl"
task :repl, [:model] do |_, args|
  require "llm"
  require "llm/tools"
  model = args[:model] || "deepseek-v4-flash"
  llm = LLM.deepseek(key: ENV["DEEPSEEK_SECRET"])
  agent = LLM::Agent.new(llm, name: "dev", concurrency: :thread, model:)
  agent.repl(path: "contexts/dev.json", tools: LLM::Tool.subclasses)
end

namespace :'models.dev' do
  desc "Download models.dev metadata"
  task :download do
    require "net/http"
    require "json"
    client = Net::HTTP.new "models.dev", 443
    client.use_ssl = true
    res = client.request Net::HTTP::Get.new("/api.json")
    case res
    when Net::HTTPOK
      models = JSON.parse(res.body)
      providers = %w[openai google anthropic xai zai deepseek deepinfra mistral].to_h { [_1, _1] }
      providers["bedrock"] = "amazon-bedrock"
      providers.each do |target, source|
        File.binwrite "data/#{target}.json", JSON.pretty_generate(models[source])
      end
    else
      warn("error: #{res.class}")
      exit 1
    end
  end
end

namespace :agents do
  desc "Runthe doctor agent"
  task :doctor do
    sh "agents/doctor/agent.rb"
  end

  desc "Run the changelog agent"
  task :changelog do
    sh "agents/changelog/agent.rb"
  end

  desc "Run the release agent"
  task :release, [:version] do |_t, args|
    sh "agents/release/agent.rb #{args[:version]}"
  end

  desc "Run the prompt agent"
  task :prompt do
    sh "agents/changelog/agent.rb"
  end

  namespace :backport do
    desc "perform backport research"
    task :research do
      sh "agents/backport/main.rb research"
    end

    desc "research license changes"
    task :license do
      sh "agents/backport/main.rb license"
    end

    desc "perform code edits"
    task :code do
      sh "agents/backport/main.rb code"
    end
  end
end

task default: %i[spec rubocop]
