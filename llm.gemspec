# frozen_string_literal: true

require_relative "lib/llm/version"

Gem::Specification.new do |spec|
  spec.name = "llm.rb"
  spec.version = LLM::VERSION
  spec.authors = ["Antar Azri", "0x1eef", "Christos Maris", "Rodrigo Serrano"]
  spec.email = ["azantar@proton.me", "0x1eef@hardenedbsd.org"]

  spec.summary = "System integration layer for LLMs, tools, MCP, and APIs in Ruby."

  spec.description = <<~DESCRIPTION
  llm.rb is a Ruby-centric system integration layer for building LLM-powered
  systems. It connects LLMs to real systems by turning APIs into tools and
  unifying MCP, providers, contexts, and application logic in one execution
  model. It supports explicit tool orchestration, concurrent execution,
  streaming, multiple MCP sources, and multiple LLM providers for production
  systems that integrate external and internal services.
  DESCRIPTION

  spec.license = "0BSD"
  spec.required_ruby_version = ">= 3.2.0"

  spec.homepage = "https://github.com/llmrb/llm.rb"
  spec.metadata["homepage_uri"] = "https://github.com/llmrb/llm.rb"
  spec.metadata["source_code_uri"] = "https://github.com/llmrb/llm.rb"
  spec.metadata["documentation_uri"] = "https://0x1eef.github.io/x/llm.rb"
  spec.metadata["changelog_uri"] = "https://0x1eef.github.io/x/llm.rb/file.CHANGELOG.html"

  spec.files = Dir[
    "README.md", "LICENSE",
    "lib/*.rb", "lib/**/*.rb",
    "data/*.json", "CHANGELOG.md",
    "llm.gemspec"
  ]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "webmock", "~> 3.24.0"
  spec.add_development_dependency "yard", "~> 0.9.37"
  spec.add_development_dependency "kramdown", "~> 2.4"
  spec.add_development_dependency "webrick", "~> 1.8"
  spec.add_development_dependency "test-cmd.rb", "~> 0.12.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "standard", "~> 1.50"
  spec.add_development_dependency "vcr", "~> 6.0"
  spec.add_development_dependency "dotenv", "~> 2.8"
  spec.add_development_dependency "net-http-persistent", "~> 4.0"
  spec.add_development_dependency "opentelemetry-sdk", "~> 1.10"
  spec.add_development_dependency "logger", "~> 1.7"
end
