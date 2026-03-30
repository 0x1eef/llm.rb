# Changelog

## Unreleased

Changes since `v4.8.0`.

### Add

- Add fiber-based concurrency with `LLM::Function::FiberGroup` and
  `LLM::Function::TaskGroup` classes for lightweight async execution.
- Add `:thread`, `:task`, and `:fiber` strategy parameter to
  `LLM::Function#spawn` for explicit concurrency control.
- Add stdio MCP client support, including remote tool discovery and
  invocation through `LLM.mcp`, `LLM::Context`, and existing function/tool
  APIs.
- Add model registry support via `LLM::Registry`, including model
  metadata lookup, pricing, modalities, limits, and cost estimation.
- Add context access to a model context window via
  `LLM::Context#context_window`.
- Add tracking of defined tools in the tool registry.
- Add `LLM::Schema::Enum`, enabling `Enum[...]` as a schema/tool
  parameter type.
- Add top-level Anthropic system instruction support using Anthropic's
  provider-specific request format.
- Add richer tracing hooks and extra metadata support for
  LangSmith/OpenTelemetry-style traces.
- Add rack/websocket and Relay-related example work, including MCP-focused
  examples.
- Add concurrent tool execution with `LLM::Function#spawn`,
  `LLM::Function::Array` (`call`, `wait`, `spawn`), and
  `LLM::Function::ThreadGroup`.
- Add `LLM::Function::ThreadGroup#alive?` method for non-blocking
  monitoring of concurrent tool execution.
- Add `LLM::Function::ThreadGroup#value` alias for `ThreadGroup#wait` for
  consistency with Ruby's `Thread#value`.

### Change

- Rename `LLM::Session` to `LLM::Context` throughout the codebase to better
  reflect the concept of a stateful interaction environment.
- Rename `LLM::Gemini` to `LLM::Google` to better reflect provider naming.
- Standardize model objects across providers around a smaller common
  interface.
- Switch registry cost internals from `LLM::Estimate` to `LLM::Cost`.
- Update image generation defaults so OpenAI and xAI consistently return
  base64-encoded image data by default.
- Update `LLM::Bot` deprecation warning from v5.0 to v6.0, giving users
  more time to migrate to `LLM::Context`.
- Rework the README and screencast documentation to better cover MCP,
  registry, contexts, prompts, concurrency, providers, and example flow.
- Expand the README with architecture, production, and provider guidance
  while improving readability and example ordering.

### Fix

- Fix local schema `$ref` resolution in `LLM::Schema::Parser`.
- Fix multiple MCP issues around stdio env handling, request IDs, registry
  interaction, tool registration, and filtering of MCP tools from the
  standard tool registry.
- Fix stream parsing issues, including chunk-splitting bugs and safer
  handling of streamed error responses.
- Fix prompt handling across contexts, agents, and provider adapters so
  prompt turns remain consistent in history and completions.
- Fix several tool/context issues, including function return wrapping,
  tool lookup after deserialization, unnamed subclass filtering, and
  thread-safety around tool registry mutations.
- Fix Google tool-call handling to preserve `thoughtSignature`.
- Fix `LLM::Tracer::Logger` argument handling.
- Fix packaging/docs issues such as registry files in the gemspec and
  stale provider docs.
- Fix Google provider handling of `nil` function IDs during context
  deserialization.
- Fix MCP stdio transport by increasing poll timeout for better
  reliability.
- Fix Google provider to properly cast non-Hash tool results into Hash
  format for API compatibility.
- Fix schema parser to support recursive normalization of `Array`,
  `LLM::Object`, and nested structures.
- Fix DeepSeek provider to tolerate malformed tool arguments.
- Fix `LLM::Function::TaskGroup#alive?` to properly delegate to
  `Async::Task#alive?`.
- Fix various RuboCop errors across the codebase.
- Fix DeepSeek provider to handle JSON that might be valid but unexpected.

### Notes

Notable merged work in this range includes:

- `feat(function): add fiber-based concurrency for async environments (#64)`
- `feat(mcp): add stdio MCP support (#134)`
- `Add LLM::Registry + cost support (#133)`
- `Consistent model objects across providers (#131)`
- `Add rack + websocket example (#130)`
- `feat(gemspec): add changelog URI (#136)`
- `feat(function): alias ThreadGroup#wait as ThreadGroup#value (#62)`
- README and screencast refresh across `#66`, `#67`, `#68`, `#71`, and
  `#72`
- `chore(bot): update deprecation warning from v5.0 to v6.0`
- `fix(deepseek): tolerate malformed tool arguments`
- `refactor(context): Rename Session as Context (#70)`

Comparison base:
- Latest tag: `v4.8.0` (`6468f2426ee125823b7ae43b4af507b125f96ffc`)
- HEAD used for this changelog: `915c48da6fda9bef1554ff613947a6ce26d382e3`
