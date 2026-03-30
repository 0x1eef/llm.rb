<p align="center">
  <a href="llm.rb"><img src="https://github.com/llmrb/llm.rb/raw/main/llm.png" width="200" height="200" border="0" alt="llm.rb"></a>
</p>
<p align="center">
  <a href="https://0x1eef.github.io/x/llm.rb?rebuild=1"><img src="https://img.shields.io/badge/docs-0x1eef.github.io-blue.svg" alt="RubyDoc"></a>
  <a href="https://opensource.org/license/0bsd"><img src="https://img.shields.io/badge/License-0BSD-orange.svg?" alt="License"></a>
  <a href="https://github.com/llmrb/llm.rb/tags"><img src="https://img.shields.io/badge/version-4.8.0-green.svg?" alt="Version"></a>
</p>

## About

llm.rb is a Ruby-centric toolkit for building real LLM-powered systems — where
LLMs are part of your architecture, not just API calls. It gives you explicit
control over contexts, tools, concurrency, and providers, so you can compose
reliable, production-ready workflows without hidden abstractions.

Built for engineers who want to understand and control their LLM systems. No
frameworks, no hidden magic — just composable primitives for building real
applications, from scripts to full systems like [Relay](https://github.com/llmrb/relay).

Jump to [Quick start](#quick-start), discover its [capabilities](#capabilities), read about
its [architecture](#architecture--execution-model) or watch the
[Screencast](https://www.youtube.com/watch?v=x1K4wMeO_QA) for a deep dive into the design
and capabilities of llm.rb.

## What Makes It Different

Most LLM libraries stop at requests and responses. llm.rb is built around the
state and execution model around them:

- **Contexts are central**
  They hold history, tools, schema, usage, cost, persistence, and execution state.
- **Tool execution is explicit**
  Run local, provider-native, and MCP tools sequentially or concurrently with threads, fibers, or async tasks.
- **One API across providers and capabilities**
  The same model covers chat, files, images, audio, embeddings, vector stores, and more.
- **Thread-safe where it matters**
  Providers are shareable, while contexts stay isolated and stateful.
- **Local metadata, fewer extra API calls**
  A built-in registry provides model capabilities, limits, pricing, and cost estimation.
- **Stdlib-only by default**
  llm.rb runs on the Ruby standard library by default, with providers lazy-loaded and optional adapters only when you want them.

## Architecture & Execution Model

llm.rb is built in layers, each providing explicit control:

```
┌─────────────────────────────────────────┐
│          Your Application               │
├─────────────────────────────────────────┤
│         Contexts & Agents               │ ← Stateful workflows
├─────────────────────────────────────────┤
│           Tools & Functions             │ ← Concurrent execution
├─────────────────────────────────────────┤
│   Unified Provider API (OpenAI, etc.)   │ ← Provider abstraction
├─────────────────────────────────────────┤
│      HTTP, JSON, Thread Safety          │ ← Infrastructure
└─────────────────────────────────────────┘
```

### Key Design Decisions

- **Thread-safe providers** - `LLM::Provider` instances are safe to share across threads
- **Thread-local contexts** - `LLM::Context` should generally be kept thread-local
- **JSON adapter system** - Swap JSON libraries (JSON/Oj/Yajl) for performance
- **Registry system** - Local metadata for model capabilities, limits, and pricing
- **Provider adaptation** - Normalizes differences between OpenAI, Anthropic, Google, and other providers
- **Structured tool execution** - Errors are captured and returned as data, not raised unpredictably
- **Function vs Tool APIs** - Choose between class-based tools and closure-based functions

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

## Quick Start

#### Concurrent Tools

llm.rb provides explicit concurrency control for tool execution. The
`wait(:thread)` method spawns each pending function in its own thread and waits
for all to complete. You can also use `:fiber` for cooperative multitasking or
`:task` for async/await patterns (requires the `async` gem). The context
automatically collects all results and reports them back to the LLM in a
single turn, maintaining conversation flow while parallelizing independent
operations:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
ctx = LLM::Context.new(llm, tools: [FetchWeather, FetchNews, FetchStock])

# Execute multiple independent tools concurrently
ctx.talk("Summarize the weather, headlines, and stock price.")
ctx.talk(ctx.functions.wait(:thread))
```

#### MCP

llm.rb integrates with the Model Context Protocol (MCP) to dynamically discover
and use tools from external servers. This example starts a filesystem MCP
server over stdio and makes its tools available to a context, enabling the LLM
to interact with the local file system through a standardized interface:

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

#### Streaming Chat

This example demonstrates llm.rb's streaming support. The `stream: $stdout`
parameter tells the context to write responses incrementally as they arrive
from the LLM. The `Context` object manages the conversation history, and
`talk()` sends your input while automatically appending both your message and
the LLM's response to the context. Streams accept any object with `#<<`,
giving you flexibility to pipe output to files, network sockets, or custom
buffers:

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

#### Tool Calling

Tools in llm.rb can be defined as classes inheriting from `LLM::Tool` or as
closures using `LLM.function`. When the LLM requests a tool call, the context
stores `Function` objects in `ctx.functions`. The `call()` method executes all
pending functions and returns their results to the LLM. Tools support
structured parameters with JSON Schema validation and automatically adapt to
each provider's API format (OpenAI, Anthropic, Google, etc.):

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

#### Structured Outputs

The `LLM::Schema` system lets you define JSON schemas that LLMs must follow.
Schemas can be defined as classes with `property` declarations or built
programmatically using a fluent interface. When you pass a schema to a context,
llm.rb automatically configures the provider's JSON mode and validates
responses against your schema. The `content!` method returns the parsed JSON
object, while errors are captured as structured data rather than raising
exceptions:

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

## Providers

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

## Production

#### Ready for production

llm.rb is designed for production use from the ground up:

- **Thread-safe providers** - Share `LLM::Provider` instances across your application
- **Thread-local contexts** - Keep `LLM::Context` instances thread-local for state isolation
- **Cost tracking** - Know your spend before the bill arrives
- **Observability** - Built-in tracing with OpenTelemetry support
- **Persistence** - Save and restore contexts across processes
- **Performance** - Swap JSON adapters and enable HTTP connection pooling
- **Error handling** - Structured errors, not unpredictable exceptions

#### Example: Thread Safety

llm.rb uses Ruby's `Monitor` class to ensure thread safety at the provider
level, allowing you to share a single provider instance across multiple threads
while maintaining state isolation through thread-local contexts. This design
enables efficient resource sharing while preventing race conditions in
concurrent applications:

```ruby
#!/usr/bin/env ruby
require "llm"

# Thread-safe providers - create once, use everywhere
llm = LLM.openai(key: ENV["KEY"])

# Each thread should have its own context for state isolation
Thread.new do
  ctx = LLM::Context.new(llm)  # Thread-local context
  ctx.talk("Hello from thread 1")
end

Thread.new do
  ctx = LLM::Context.new(llm)  # Thread-local context
  ctx.talk("Hello from thread 2")
end
```

#### Example: Performance Tuning

llm.rb's JSON adapter system lets you swap JSON libraries for better
performance in high-throughput applications. The library supports stdlib JSON,
Oj, and Yajl, with Oj typically offering the best performance. Additionally,
you can enable HTTP connection pooling using the optional `net-http-persistent`
gem to reduce connection overhead in production environments:

```ruby
#!/usr/bin/env ruby
require "llm"

# Swap JSON libraries for better performance
LLM.json = :oj  # Use Oj for faster JSON parsing

# Enable HTTP connection pooling for high-throughput applications
llm = LLM.openai(key: ENV["KEY"]).persist!  # Uses net-http-persistent when available
```

#### Example: Model Registry

llm.rb includes a local model registry that provides metadata about model
capabilities, pricing, and limits without requiring API calls. The registry is
shipped with the gem and sourced from https://models.dev, giving you access to
up-to-date information about context windows, token costs, and supported
modalities for each provider:

```ruby
#!/usr/bin/env ruby
require "llm"

# Access model metadata, capabilities, and pricing
registry = LLM.registry_for(:openai)
model_info = registry.limit(model: "gpt-4.1")
puts "Context window: #{model_info.context} tokens"
puts "Cost: $#{model_info.cost.input}/1M input tokens"
```

## More Examples

#### Responses API

llm.rb also supports OpenAI's Responses API through `llm.responses` and
`ctx.respond`. This API can maintain response state server-side and can reduce
how much conversation state needs to be sent on each turn:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
ctx = LLM::Context.new(llm)

ctx.respond("Your task is to answer the user's questions", role: :developer)
res = ctx.respond("What is the capital of France?")
puts res.output_text
```

#### Context Persistence

Contexts can be serialized and restored across process boundaries. This makes
it possible to persist conversation state in a file, database, or queue and
resume work later:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
ctx = LLM::Context.new(llm)
ctx.talk("Hello")
ctx.talk("Remember that my favorite language is Ruby")
ctx.save(path: "context.json")

restored = LLM::Context.new(llm)
restored.restore(path: "context.json")
res = restored.talk("What is my favorite language?")
puts res.content
```

#### Agents

Agents in llm.rb are reusable, preconfigured assistants that automatically
execute tool calls and maintain conversation state. Unlike contexts which
require manual tool execution, agents automatically handle the tool call loop,
making them ideal for autonomous workflows where you want the LLM to
independently use available tools to accomplish tasks:

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

#### Cost Tracking

llm.rb provides built-in cost estimation that works without making additional
API calls. The cost tracking system uses the local model registry to calculate
estimated costs based on token usage, giving you visibility into spending
before bills arrive. This is particularly useful for monitoring usage in
production applications and setting budget alerts:

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

#### Multimodal Prompts

Contexts provide helpers for composing multimodal prompts from URLs, local
files, and provider-managed remote files. These tagged objects let providers
adapt the input into the format they expect:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
ctx = LLM::Context.new(llm)

res = ctx.talk ["Describe this image", ctx.image_url("https://example.com/cat.jpg")]
puts res.content
```

#### Audio Generation

llm.rb supports OpenAI's audio API for text-to-speech generation, allowing you
to create speech from text with configurable voices and output formats. The
audio API returns binary audio data that can be streamed directly to files or
other IO objects, enabling integration with multimedia applications:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
res = llm.audio.create_speech(input: "Hello world")
IO.copy_stream res.audio, File.join(Dir.home, "hello.mp3")
```

#### Image Generation

llm.rb provides access to OpenAI's DALL-E image generation API through a
unified interface. The API supports multiple response formats including
base64-encoded images and temporary URLs, with automatic handling of binary
data streaming for efficient file operations:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
res = llm.images.create(prompt: "a dog on a rocket to the moon")
IO.copy_stream res.images[0], File.join(Dir.home, "dogonrocket.png")
```

#### Embeddings

llm.rb's embedding API generates vector representations of text for semantic
search and retrieval-augmented generation (RAG) workflows. The API supports
batch processing of multiple inputs and returns normalized vectors suitable for
vector similarity operations, with consistent dimensionality across providers:

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

## Real-World Example: Relay

See how these pieces come together in a complete application architecture with
[Relay](https://github.com/llmrb/relay), a production-ready LLM application
built on llm.rb that demonstrates:

- Context management across requests
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
