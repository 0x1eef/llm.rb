<p align="center">
  <a href="llm.rb"><img src="https://github.com/llmrb/llm.rb/raw/main/llm.png" width="200" height="200" border="0" alt="llm.rb"></a>
</p>
<p align="center">
  <a href="https://0x1eef.github.io/x/llm.rb?rebuild=1"><img src="https://img.shields.io/badge/docs-0x1eef.github.io-blue.svg" alt="RubyDoc"></a>
  <a href="https://opensource.org/license/0bsd"><img src="https://img.shields.io/badge/License-0BSD-orange.svg?" alt="License"></a>
  <a href="https://github.com/llmrb/llm.rb/tags"><img src="https://img.shields.io/badge/version-4.12.0-green.svg?" alt="Version"></a>
</p>

## About

llm.rb is a Ruby library for building AI workflows that need to talk to the
rest of your software. It gives you one execution model for providers, tools,
MCP servers, streaming, schemas, files, and state, so the same core
primitives can power chat flows, tool-enabled agents, multimodal prompts,
persisted contexts, and provider-backed workflows.

It is built for engineers who want control over how these systems run. llm.rb
stays close to Ruby, runs on the standard library by default, loads optional
pieces only when needed, and remains easy to extend. It also works well in
Rails or ActiveRecord applications, where a small wrapper around context
persistence is enough to save and restore long-lived conversation state across
requests, jobs, or retries.

## Architecture

```
    External MCP      Internal MCP      OpenAPI / REST
         │                 │                  │
         └────────── Tools / MCP Layer ───────┘
                            │
                      llm.rb Contexts
                            │
                       LLM Providers
                 (OpenAI, Anthropic, etc.)
                            │
                      Your Application
```

## Differentiators

Most LLM libraries stop at requests and responses. llm.rb is built around the
state and execution model behind them.

- **A system layer, not just an API wrapper**  
  Put providers, tools, MCP servers, and application APIs behind one runtime
  model instead of stitching them together by hand.
- **Contexts are central**  
  Keep history, tools, schema, usage, persistence, and execution state in one
  place instead of spreading them across your app.
- **Contexts can be serialized**  
  Save and restore live state for jobs, databases, retries, or long-running
  workflows.
- **Tools are explicit**  
  Run local tools, provider-native tools, and MCP tools through the same path
  with fewer special cases.
- **Streaming and tool execution work together**  
  Start tool work while output is still streaming so you can hide latency
  instead of waiting for turns to finish.
- **Concurrency is a first-class feature**  
  Use threads, fibers, or async tasks without rewriting your tool layer.
- **It scales from scripts to long-lived systems**  
  The same primitives work for one-off scripts, background jobs, and more
  demanding application workloads with streaming, persistence, and tracing.
- **MCP is built in**  
  Connect to MCP servers over stdio or HTTP without bolting on a separate
  integration stack.
- **Providers are normalized, not flattened**  
  Share one API surface across providers without losing access to provider-
  specific capabilities where they matter.
- **It is highly pluggable**  
  Add tools, swap providers, change JSON backends, plug in tracing, or layer
  internal APIs and MCP servers into the same execution path.
- **Advanced workloads are built in, not bolted on**  
  Streaming, concurrent tool execution, persistence, tracing, and MCP support
  all fit the same runtime model.
- **Thread boundaries are clear**  
  Providers are shareable. Contexts are stateful and should stay thread-local.
- **Local model metadata is included**  
  Model capabilities, pricing, and limits are available locally without extra
  API calls.
- **Runs on the stdlib**  
  Start with Ruby's standard library and add extra dependencies only when you
  need them.

## Capabilities

- **Chat & Contexts** — stateless and stateful interactions with persistence
- **Context Serialization** — save and restore state across processes or time
- **Streaming** — visible output, reasoning output, tool-call events
- **Tool Calling** — class-based tools and closure-based functions
- **Run Tools While Streaming** — overlap model output with tool latency
- **Concurrent Execution** — threads, async tasks, and fibers
- **Agents** — reusable assistants with tool auto-execution
- **Structured Outputs** — JSON Schema-based responses
- **Responses API** — stateful response workflows where providers support them
- **MCP Support** — stdio and HTTP MCP clients with prompt and tool support
- **Multimodal Inputs** — text, images, audio, documents, URLs
- **Audio** — speech generation, transcription, translation
- **Images** — generation and editing
- **Files API** — upload and reference files in prompts
- **Embeddings** — vector generation for search and RAG
- **Vector Stores** — retrieval workflows
- **Cost Tracking** — local cost estimation without extra API calls
- **Observability** — tracing, logging, telemetry
- **Model Registry** — local metadata for capabilities, limits, pricing
- **Persistent HTTP** — optional connection pooling for providers and MCP

## Installation

```bash
gem install llm.rb
```

## Example

```ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
ctx = LLM::Context.new(llm, stream: $stdout)

loop do
  print "> "
  ctx.talk(STDIN.gets || break)
  puts
end
```

## Resources

- [resources/deepdive.md](resources/deepdive.md) is the examples guide.
- [_examples/relay](./_examples/relay) shows a real application built on top
  of llm.rb.
- [doc site](https://0x1eef.github.io/x/llm.rb?rebuild=1) has the API docs.

## License

[BSD Zero Clause](https://choosealicense.com/licenses/0bsd/)
<br>
See [LICENSE](./LICENSE)
