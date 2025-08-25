# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

cassettes = File.join(__dir__, "spec", "fixtures", "cassettes")
remotes = %w[openai gemini anthropic deepseek]
locals = %w[ollama llamacpp]

desc "Run linter"
task :rubocop do
  sh "bundle exec rubocop"
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
    specs = Dir["spec/{#{remotes.join(",")}}/**/*.rb"].shuffle
    sh "bundle exec rspec #{specs.join(' ')}"
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
  sh "bundle exec rspec spec"
end

desc "Start a console with all providers loaded"
task :console do
  require "llm"
  require "dotenv"
  Dotenv.load
  openai = LLM.openai(key: ENV["OPENAI_SECRET"])
  gemini = LLM.gemini(key: ENV["GEMINI_SECRET"])
  anthropic = LLM.anthropic(key: ENV["ANTHROPIC_SECRET"])
  deepseek = LLM.deepseek(key: ENV["DEEPSEEK_SECRET"])
  xai = LLM.xai(key: ENV["XAI_SECRET"])
  binding.irb
end

task default: %i[spec rubocop]
