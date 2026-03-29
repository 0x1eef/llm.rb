<p align="center">
  <a href="llm.rb"><img src="https://github.com/llmrb/llm.rb/raw/main/llm.png" width="200" height="200" border="0" alt="llm.rb"></a>
</p>
<p align="center">
  <a href="https://0x1eef.github.io/x/llm.rb?rebuild=1"><img src="https://img.shields.io/badge/docs-0x1eef.github.io-blue.svg" alt="RubyDoc"></a>
  <a href="https://opensource.org/license/0bsd"><img src="https://img.shields.io/badge/License-0BSD-orange.svg?" alt="License"></a>
  <a href="https://github.com/llmrb/llm.rb/tags"><img src="https://img.shields.io/badge/version-4.8.0-green.svg?" alt="Version"></a>
</p>

## About

llm.rb is a Ruby-native toolkit for building real LLM-powered systems — where LLMs are part of your architecture, not just API calls. It gives you explicit control over sessions, tools, concurrency, and providers, so you can compose reliable, production-ready workflows without hidden abstractions.

Built for engineers who want to understand and control their LLM systems. No frameworks, no hidden magic — just composable primitives for building real applications, from scripts to full systems like [Relay](https://github.com/llmrb/relay).

Rails gives you conventions for building web apps. llm.rb gives you primitives for building LLM systems.

## What Makes It Different

Most AI libraries treat LLMs as request/response APIs. llm.rb treats them as **components in a system**.

- **Explicit over implicit** — Sessions, tools, and concurrency are first-class objects you control
- **Composable over monolithic** — Build workflows from simple primitives, not complex frameworks
- **Observable over opaque** — Built-in tracing and cost tracking for production systems
- **Provider-agnostic over vendor-locked** — Switch between OpenAI, Anthropic, Ollama, etc. without rewriting
- **Minimal by default** — stdlib-only with zero runtime dependencies; optional features are lazy-loaded when needed

## Who It's For

llm.rb is built for:

- **Solo builders & indie hackers** who care about control, cost, and flexibility
- **Systems engineers moving into AI** who understand threads, processes, and architecture
- **Backend engineers building internal tools** who need reliability, observability, and cost tracking
- **Developers burned by over-engineered frameworks** who want something they can reason about

Build things like internal copilots, automation tools, or self-hosted AI services — with explicit control over every component.

## Quick Start

### Run multiple tools concurrently

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
ses = LLM::Session.new(llm, tools: [FetchWeather, FetchNews, FetchStock])

# Execute multiple independent tools concurrently
ses.talk("Summarize the weather, headlines, and stock price.")
ses.talk(ses.functions.wait(:thread))
```

### Basic Session

The `LLM::Session` class provides a session with an LLM provider that maintains conversation history and context across multiple requests:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
ses = LLM::Session.new(llm, stream: $stdout)
loop do
  print "> "
  ses.talk(STDIN.gets || break)
  puts
end
```

### Structured Outputs

Define JSON schemas for structured responses:

```ruby
#!/usr/bin/env ruby
require "llm"
require "pp"

class Report < LLM::Schema
  property :category, Enum["performance", "security", "outage"], "Report category", required: true
  property :summary, String, "Short summary", required: true
  property :services, Array[String], "Impacted services", required: true
  property :timestamp, String, "When it happened", optional: true
end

llm = LLM.openai(key: ENV["KEY"])
ses = LLM::Session.new(llm, schema: Report)
res = ses.talk("Structure this report: 'Database latency spiked at 10:42 UTC, causing 5% request timeouts for 12 minutes.'")
pp res.content!

# {
#   "category" => "performance",
#   "summary" => "Database latency spiked, causing 5% request timeouts for 12 minutes.",
#   "services" => ["Database"],
#   "timestamp" => "2024-06-05T10:42:00Z"
# }
```

### Tool Calling

Define callable tools that the model can invoke:

```ruby
#!/usr/bin/env ruby
require "llm"

class System < LLM::Tool
  name "system"
  description "Run a shell command"
  param :command, String, "Command to execute", required: true

  def call(command:)
    {success: system(command)}
  end
end

llm = LLM.openai(key: ENV["KEY"])
ses = LLM::Session.new(llm, tools: [System])
ses.talk("Run `date`.")
ses.talk(ses.functions.call) # report return value to the LLM
```

## Execution Model

llm.rb provides a complete runtime for LLM workflows:

- **Flexible tool definitions** — Define tools as classes or closures depending on your use case
- **Explicit concurrency model** — Execute tools with threads, async tasks, or fibers using a unified API
- **Provider adaptation** — Normalizes differences between OpenAI, Anthropic, Google, and other providers
- **Structured tool execution** — Errors are captured and returned as data, not raised unpredictably
- **Thread-safe by design** — Internal synchronization ensures safe use across threads
- **Function vs Tool APIs** — Choose between class-based tools and closure-based functions

## Capabilities

llm.rb provides a complete set of primitives for building LLM-powered systems:

- **Chat & Sessions** — stateless and stateful conversations with persistence
- **Streaming** — real-time responses across providers
- **Tool Calling** — define and execute functions with automatic orchestration
- **Concurrent Execution** — threads, async tasks, and fibers
- **Agents** — reusable, preconfigured assistants with tool auto-execution
- **Structured Outputs** — JSON schema-based responses
- **MCP Support** — integrate external tool servers dynamically
- **Multimodal Inputs** — text, images, audio, documents, URLs
- **Audio** — text-to-speech, transcription, translation
- **Images** — generation and editing
- **Files API** — upload and reference files in prompts
- **Embeddings** — vector generation for search and RAG
- **Vector Stores** — OpenAI-based retrieval workflows
- **Cost Tracking** — estimate usage without API calls
- **Observability** — tracing, logging, telemetry
- **Model Registry** — local metadata for capabilities, limits, pricing

## Advanced Capabilities

For more advanced use cases, llm.rb also provides:

- **Session persistence** — save and restore conversations across processes (`#save`, `#restore`)
- **Prompt composition** — build reusable prompts independent of sessions
- **HTTP connection pooling** — optional persistent connections for performance
- **Telemetry integration** — OpenTelemetry support with exporters and tracing
- **Provider capabilities** — support varies by provider (audio, images, files, etc.)
- **Execution control** — spawn and manage concurrent tool execution explicitly
- **Multimodal inputs** — structured handling of images, files, and URLs

## More Examples

### MCP (Model Context Protocol)

Start an MCP server over stdio and use its tools in a session:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
mcp = LLM.mcp(stdio: {argv: ["npx", "-y", "@modelcontextprotocol/server-filesystem", Dir.pwd]})

begin
  mcp.start
  ses = LLM::Session.new(llm, stream: $stdout, tools: mcp.tools)
  ses.talk("List the directories in this project.")
  ses.talk(ses.functions.map(&:call)) while ses.functions.any?
ensure
  mcp.stop
end
```

### Agents

Define reusable, preconfigured assistants with defaults for model, tools, schema, and instructions:

```ruby
#!/usr/bin/env ruby
require "llm"

class SystemAdmin < LLM::Agent
  model "gpt-4.1"
  instructions "You are a Linux system admin"
  tools Shell
  schema Result
end

llm = LLM.openai(key: ENV["KEY"])
agent = SystemAdmin.new(llm)
res = agent.talk("Run 'date'")
```

### Cost Tracking

Estimate costs without making additional API calls:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
ses = LLM::Session.new(llm)
ses.talk "Hello"
puts "Estimated cost so far: $#{ses.cost}"
ses.talk "Tell me a joke"
puts "Estimated cost so far: $#{ses.cost}"
```

### Audio Generation

Create speech from text:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
res = llm.audio.create_speech(input: "Hello world")
IO.copy_stream res.audio, File.join(Dir.home, "hello.mp3")
```

### Image Generation

Create images from prompts:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
res = llm.images.create(prompt: "a dog on a rocket to the moon")
IO.copy_stream res.images[0], File.join(Dir.home, "dogonrocket.png")
```

### Embeddings

Get vector embeddings for semantic search:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
res = llm.embed(["programming is fun", "ruby is a programming language", "sushi is art"])
puts res.class
puts res.embeddings.size
puts res.embeddings[0].size

# LLM::Response
# 3
# 1536
```

## Architecture: Systems, Not Magic

llm.rb is designed for engineers who want to *understand* their LLM systems, not just use them:

- **Thread-safe providers** — Share connections across your application, not per-request overhead
- **Stateful sessions** — Keep conversation context local to workflows, not global state
- **Composable tools** — Define once, reuse everywhere with clear execution boundaries
- **Explicit concurrency** — Choose threads, async tasks, or fibers based on your workload
- **Trackable costs** — Know what you're spending before the bill arrives

## Real-World Example: Relay

See how these pieces come together in a complete application architecture with [Relay](https://github.com/llmrb/relay), a production-ready LLM application built on llm.rb that demonstrates:

- Session management across requests
- Tool composition and execution
- Concurrent workflows
- Cost tracking and observability
- Production deployment patterns

Watch the screencast:

[![Watch the llm.rb screencast](https://img.youtube.com/vi/Jb7LNUYlCf4/maxresdefault.jpg)](https://www.youtube.com/watch?v=x1K4wMeO_QA)

## Installation

```bash
gem install llm.rb
```

## License

[BSD Zero Clause](https://choosealicense.com/licenses/0bsd/)
<br>
See [LICENSE](./LICENSE)