# frozen_string_literal: true

require_relative "lib/llm/version"

Gem::Specification.new do |spec|
  spec.name = "llm.rb"
  spec.version = LLM::VERSION
  spec.authors = ["Antar Azri", "0x1eef", "Christos Maris", "Rodrigo Serrano"]
  spec.email = ["azantar@proton.me", "0x1eef@hardenedbsd.org"]

  spec.summary = "System integration layer for LLMs, tools, MCP, and APIs in Ruby."

  spec.description = <<~DESCRIPTION
  llm.rb is a runtime for building AI systems that integrate directly with your
  application. It is not just an API wrapper. It provides a unified execution
  model for providers, tools, MCP servers, streaming, schemas, files, and
  state.

  It is built for engineers who want control over how these systems run.
  llm.rb stays close to Ruby, runs on the standard library by default, loads
  optional pieces only when needed, and remains easy to extend. It also works
  well in Rails or ActiveRecord applications, where a small wrapper around
  context persistence is enough to save and restore long-lived conversation
  state across requests, jobs, or retries.

  Most LLM libraries stop at request/response APIs. Building real systems
  means stitching together streaming, tools, state, persistence, and external
  services by hand. llm.rb provides a single execution model for all of these,
  so they compose naturally instead of becoming separate subsystems.
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
