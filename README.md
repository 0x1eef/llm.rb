<p align="center">
  <a href="llm.rb"><img src="https://github.com/llmrb/llm.rb/raw/main/llm.png" width="200" height="200" border="0" alt="llm.rb"></a>
</p>
<p align="center">
  <a href="https://0x1eef.github.io/x/llm.rb?rebuild=1"><img src="https://img.shields.io/badge/docs-0x1eef.github.io-blue.svg" alt="RubyDoc"></a>
  <a href="https://opensource.org/license/0bsd"><img src="https://img.shields.io/badge/License-0BSD-orange.svg?" alt="License"></a>
  <a href="https://github.com/llmrb/llm.rb/tags"><img src="https://img.shields.io/badge/version-4.8.0-green.svg?" alt="Version"></a>
</p>

## About

llm.rb is a Ruby-native toolkit for building real LLM-powered systems — where
LLMs are part of your architecture, not just API calls. It gives you explicit
control over contexts, tools, concurrency, and providers, so you can compose
reliable, production-ready workflows without hidden abstractions.

Built for engineers who want to understand and control their LLM systems. No
frameworks, no hidden magic — just composable primitives for building real
applications, from scripts to full systems like [Relay](https://github.com/llmrb/relay).

Rails gives you conventions for building web apps. llm.rb gives you primitives
for building LLM systems.

## What Makes It Different

Most LLM libraries focus on request/response calls. llm.rb gives you the
state and execution model around them.

- **Contexts are first-class** — state, history, tools, and cost all live in one object
- **Tools are part of the runtime** — tool calls can be run sequentially or concurrently
- **Providers share one API** — switch between OpenAI, Anthropic, Google, etc.
- **Built for inspection** — tracing, usage, and cost tracking are available from the same objects you already use
- **Minimal by default** — stdlib-only at runtime; optional features are lazy-loaded when needed

## Runtime & Execution

llm.rb treats LLM interactions as workflows:

- **Context** manages state and history
- **Tools** define execution boundaries
- **Functions** run within the context
- **Results** are composed back into the system

## Quick Start

### Concurrent tools

llm.rb supports concurrent tool execution using threads, fibers, or async
tasks. Here's how to execute multiple independent tools concurrently with
threads:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
ctx = LLM::Context.new(llm, tools: [FetchWeather, FetchNews, FetchStock])

# Execute multiple independent tools concurrently
ctx.talk("Summarize the weather, headlines, and stock price.")
ctx.talk(ctx.functions.wait(:thread))
```

### Context

A context is a single conversation with an LLM that keeps track of everything:
the messages exchanged, any tools you've given it access to, and the costs
incurred. As you interact with the LLM, the context accumulates this
information so you can maintain a coherent conversation or workflow. As the
program runs, `ctx` accumulates messages, tool state, usage, and cost:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
ctx = LLM::Context.new(llm, stream: $stdout)
loop do
  print "> "
  ctx.talk(STDIN.gets || break)
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
ctx = LLM::Context.new(llm, schema: Report)
res = ctx.talk("Structure this report: 'Database latency spiked at 10:42 UTC, causing 5% request timeouts for 12 minutes.'")
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
ctx = LLM::Context.new(llm, tools: [System])
ctx.talk("Run `date`.")
ctx.talk(ctx.functions.call) # report return value to the LLM
```

## Supported Providers

llm.rb supports multiple LLM providers with a unified API.
All providers share the same context, tool, and concurrency interfaces, making
it easy to switch between cloud and local models:

- **OpenAI** (`LLM.openai`)
- **Anthropic** (`LLM.anthropic`)
- **Google** (`LLM.google`)
- **DeepSeek** (`LLM.deepseek`)
- **xAI** (`LLM.xai`)
- **zAI** (`LLM.zai`)
- **Ollama** (`LLM.ollama`)
- **Llama.cpp** (`LLM.llamacpp`)

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

- **Chat & Contexts** — stateless and stateful interactions with persistence
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

- **Context persistence** — save and restore interactions across processes (`#save`, `#restore`)
- **Prompt composition** — build reusable prompts independent of contexts
- **HTTP connection pooling** — optional persistent connections for performance
- **Telemetry integration** — OpenTelemetry support with exporters and tracing
- **Provider capabilities** — support varies by provider (audio, images, files, etc.)
- **Execution control** — spawn and manage concurrent tool execution explicitly
- **Multimodal inputs** — structured handling of images, files, and URLs

## More Examples

### MCP (Model Context Protocol)

Start an MCP server over stdio and use its tools in a context:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
mcp = LLM.mcp(stdio: {argv: ["npx", "-y", "@modelcontextprotocol/server-filesystem", Dir.pwd]})

begin
  mcp.start
  ctx = LLM::Context.new(llm, stream: $stdout, tools: mcp.tools)
  ctx.talk("List the directories in this project.")
  ctx.talk(ctx.functions.map(&:call)) while ctx.functions.any?
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
ctx = LLM::Context.new(llm)
ctx.talk "Hello"
puts "Estimated cost so far: $#{ctx.cost}"
ctx.talk "Tell me a joke"
puts "Estimated cost so far: $#{ctx.cost}"
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
- **Stateful contexts** — Keep interaction state local to workflows, not global state
- **Composable tools** — Define once, reuse everywhere with clear execution boundaries
- **Explicit concurrency** — Choose threads, async tasks, or fibers based on your workload
- **Trackable costs** — Know what you're spending before the bill arrives

## Real-World Example: Relay

See how these pieces come together in a complete application architecture with
[Relay](https://github.com/llmrb/relay), a production-ready LLM application
built on llm.rb that demonstrates:

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