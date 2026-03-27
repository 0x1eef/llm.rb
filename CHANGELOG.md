# Changelog

## Unreleased

Changes since `v4.8.0`.

### Added

- Added stdio MCP client support, including remote tool discovery and invocation through `LLM.mcp`, `LLM::Session`, and existing function/tool APIs.
- Added model registry support via `LLM::Registry`, including model metadata lookup, pricing, modalities, limits, and cost estimation.
- Added session access to a model context window via `LLM::Session#context_window`.
- Added tracking of defined tools in the tool registry.
- Added `LLM::Schema::Enum`, enabling `Enum[...]` as a schema/tool parameter type.
- Added top-level Anthropic system instruction support using Anthropic's provider-specific request format.
- Added richer tracing hooks and extra metadata support for LangSmith/OpenTelemetry-style traces.
- Added rack/websocket and Relay-related example work, including MCP-focused examples.

### Changed

- Renamed `LLM::Gemini` to `LLM::Google` to better reflect provider naming.
- Standardized model objects across providers around a smaller common interface.
- Switched registry cost internals from `LLM::Estimate` to `LLM::Cost`.
- Updated image generation defaults so OpenAI and xAI consistently return base64-encoded image data by default.
- Expanded README and screencast documentation for MCP, registry, context windows, enums, prompts, and concurrency.

### Fixed

- Fixed local schema `$ref` resolution in `LLM::Schema::Parser`.
- Fixed multiple MCP issues around stdio env handling, request IDs, registry interaction, tool registration, and filtering of MCP tools from the standard tool registry.
- Fixed stream parsing issues, including chunk-splitting bugs and safer handling of streamed error responses.
- Fixed prompt handling across sessions, agents, and provider adapters so prompt turns remain consistent in history and completions.
- Fixed several tool/session issues, including function return wrapping, tool lookup after deserialization, unnamed subclass filtering, and thread-safety around tool registry mutations.
- Fixed Google tool-call handling to preserve `thoughtSignature`.
- Fixed `LLM::Tracer::Logger` argument handling.
- Fixed packaging/docs issues such as registry files in the gemspec and stale provider docs.

### Notes

Notable merged work in this range includes:

- `feat(mcp): add stdio MCP support (#134)`
- `Add LLM::Registry + cost support (#133)`
- `Consistent model objects across providers (#131)`
- `Add rack + websocket example (#130)`

Comparison base:
- Latest tag: `v4.8.0` (`6468f2426ee125823b7ae43b4af507b125f96ffc`)
- HEAD used for this changelog: `2d1ddb3d9897e0e907976bf1e1e950291a4c96a6`
