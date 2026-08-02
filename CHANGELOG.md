<p align="center">
  <a href="https://r.uby.dev">
    <img
      src="https://github.com/r-uby-dev/llm.rb/raw/main/rubydev.svg"
      width="400"
      height="200"
      border="0"
      alt="a r.uby.dev project"
     >
  </a>
</p>

> Changelog <br>
> a [r.uby.dev](https://r.uby.dev) project

## What's next

### Breaking

* **replace the transformer setter with `LLM::Transformer`** <br>
  The previous `transformer=` setter and 3-argument
  `call(ctx, prompt, params)` interface on `LLM::Context` have been
  replaced by the new
  [`LLM::Transformer`](https://r.uby.dev/api-docs/llm.rb/LLM/Transformer.html)
  class interface. Configure a transformer class through `transformer:`
  and options through `transformer_options:` instead.

* **cli: scope session persistence per provider and directory** <br>
  `bin/llm.rb` no longer shares a single session file between providers.
  Each provider now has a `~/.llm.rb/<provider>.json` file that maps the
  current working directory to a UUID-scoped session file under
  `~/.llm.rb/<provider>/<uuid>.json`, so sessions are scoped to both the
  provider and the directory they were started in.

* **cli: harden the executable against bad inputs** <br>
  `bin/llm.rb` now prints an error message followed by the help menu and
  exits with status 1 when the `-p` switch is given without an argument or
  when an unknown option is passed. Previously unknown options produced a
  warning but the run continued. The session-file lookup also no longer
  rewrites `~/.llm.rb/<provider>.json` when it already exists.

### Core

* **add `LLM::Provider#build_messages` for assembling outgoing messages** <br>
  [`LLM::Provider#build_messages`](https://r.uby.dev/api-docs/llm.rb/LLM/Provider.html#build_messages-instance_method)
  normalizes a prompt into `LLM::Message` objects and prepends the existing
  history, replacing the per-provider `build_complete_messages`
  implementation. The method is idempotent: prompts that are already
  [`LLM::Message`](https://r.uby.dev/api-docs/llm.rb/LLM/Message.html)
  instances or arrays of messages are returned as-is.

* **copy the `params` hash in `LLM::Context` and `LLM::Agent`** <br>
  [`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html) and
  [`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html) now copy
  the `params` hash in their constructors before mutating it, leaving the
  caller's hash untouched. Previously the constructors deleted keys from
  the caller's hash in place.

* **gemspec: ship the deepdive sub-files in the gem** <br>
  The gemspec now includes `resources/deepdive/*/*.md` in the gem
  package, so the full deepdive guide (fundamentals, advanced,
  protocols, and everything-else chapters) is available after
  installation.

### Transformer

* **add `LLM::Transformer` for rewriting messages before they reach the provider** <br>
  [`LLM::Transformer`](https://r.uby.dev/api-docs/llm.rb/LLM/Transformer.html)
  is a new superclass for message transformers. A transformer is bound to a
  context and rewrites a single message before it is sent to the provider,
  which makes it possible to redact personal information or rewrite any
  message before it goes out over the wire. Each subclass implements
  `call(message:, **opts)` and returns the message to send, either by
  mutating it in place or returning a new one.
  [`LLM::Transformer::Null`](https://r.uby.dev/api-docs/llm.rb/LLM/Transformer/Null.html)
  is a no-op transformer used as the default.

* **hook the transformer API into `LLM::Context`** <br>
  [`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html) now
  accepts `transformer:` (a transformer class defaulting to
  `LLM::Transformer::Null`) and `transformer_options:` (a hash forwarded to
  the transformer's `call` method). The transformer runs on the most recent
  message in both chat and responses turns.
  [`LLM::Stream#on_transform`](https://r.uby.dev/api-docs/llm.rb/LLM/Stream.html#on_transform-instance_method)
  and
  [`LLM::Stream#on_transform_finish`](https://r.uby.dev/api-docs/llm.rb/LLM/Stream.html#on_transform_finish-instance_method)
  now receive the transformer instance as their single argument.

### Tool

* **add `LLM::Tool.set` for bulk-assigning tool properties** <br>
  [`LLM::Tool.set`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html#set-class_method)
  accepts a hash of `name`, `description`, `parameters`, `required`, and
  `defaults` to configure a tool subclass in a single call. Parameters are
  defined as tuples of `[name, type, description, options]`, matching the
  same interface as the existing `parameter` DSL. Unknown keys raise
  `KeyError`.

### Change

* **openai: default to `gpt-5.6-luna`** <br>
  The default OpenAI chat model has changed from `gpt-5.4-mini` to
  `gpt-5.6-luna`. The new model is OpenAI's fastest and most affordable
  option, matching the kind of default llm.rb aims for.

### Repl

* **center the buffer with 20% gutters** <br>
  The curses-based REPL now centers
  [`LLM::Repl::Buffer`](https://r.uby.dev/api-docs/llm.rb/LLM/Repl/Buffer.html)
  in a content area that is 60% of the terminal width, with an unused 20%
  gutter on each side. The drawing area is based on the available rows and
  columns instead of a fixed 80-column width, and `Buffer#wrap` now
  hard-breaks words that overflow the width onto the next row, fixing a
  bug where a word could be cut off between rows.

* **apply markdown to previous messages** <br>
  The curses-based REPL now renders every message in the buffer with
  markdown styling, including messages that were already present when
  the session started or restored from disk. Previously only newly
  streamed responses were styled; older messages fell back to plain
  text.

* **add `LLM::Repl#sender` for the user label** <br>
  [`LLM::Repl#sender`](https://r.uby.dev/api-docs/llm.rb/LLM/Repl.html#sender-instance_method)
  returns the label used for user messages in the curses-based REPL. It
  defaults to `"You"` (previously `"user"`), and the buffer layout now
  places each label on its own line followed by the message content and a
  blank line.

* **add `LLM::Repl::Color` for coloring the curses UI** <br>
  Add
  [`LLM::Repl::Color`](https://r.uby.dev/api-docs/llm.rb/LLM/Repl/Color.html)
  as a new module that returns Curses color bitmasks. `Color.enable`
  initializes 8 color pairs, and methods like `Color.blue` return the
  corresponding `Curses.color_pair(X)` bitmask, which can be bitwise
  OR'ed with other attributes such as `Curses::A_BOLD`. User labels in
  the REPL are now rendered in blue instead of plain bold text.

* **split on words rather than characters** <br>
  `LLM::Repl::Buffer#wrap` now breaks text on word boundaries instead of
  wrapping one character at a time. A word that does not fit on the
  current row moves to the next, and only a single word longer than the
  whole width is hard-broken, so text is never clipped by the window.

* **render kramdown typographic symbols and smart quotes** <br>
  Fix a bug where certain character sequences such as `...` were not
  rendered at all in the curses-based REPL. Kramdown parses them into
  `:typographic_sym` and `:smart_quote` nodes, which previously fell
  through to the children clause and were dropped. The markdown renderer
  now maps them to their unicode equivalents: ellipsis, en and em
  dashes, guillemets, and single and double quotation marks.

* **apply colors to the markdown renderer** <br>
  The curses-based REPL now renders markdown with the `LLM::Repl::Color`
  palette: headers and strong text in white, code spans and code blocks
  in green, and links in underlined green, on the black background.
  Previously markdown styling used bold, underline, and reverse video
  attributes only.

### Registry

* **refresh model metadata across providers** <br>
  Update `data/*.json` files with current provider model listings and
  pricing.

## v13.1.0

Changes since `v13.0.0`.

This release adds `LLM::Agent` class DSL attributes (`path`, `description`),
extends skills with file-path loading and the `tools: all` directive, adds new
built-in tools (`LLM::Tool::Ruby`, `LLM::Tool::EditFile`), introduces the
`LLM::Tracer::PrettyLogger` for human-readable tracing, renames `Transcript`
to `Buffer` across the REPL, ships a `bin/llm.rb` CLI entry point, and fixes
several agent and tool bugs around persistence, interruption, and naming.

### Core

* **add post install message with deepdive link** <br>
  The gemspec now includes a `post_install_message` that points users to
  the deepdive guide at `https://r.uby.dev/llm/deepdive` after installation,
  making it easier for new users to discover the project documentation.

### Agent

* **add `description` class DSL and instance method** <br>
  [`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html) now
  has a `description` class DSL (`description "release engineer"`) and a
  corresponding `#description` instance method. The description is an
  optional self-documenting string that serves as a brief summary of the
  agent's purpose. It can be set via the class DSL,
  `LLM::Agent.set(description: ...)`, or `LLM::Agent.new(description: ...)`.

* **add `path` class DSL and instance method** <br>
  [`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html) now
  has a `path` class DSL (`path "contexts/admin.json"`) and a
  corresponding `#path` instance method. When a path is set, the agent
  automatically restores its conversation history from that file on
  initialization and saves it back after each `talk` or `ask` turn,
  making session persistence across process restarts transparent.

### Skills

* **accept a path to a markdown file** <br>
  [`LLM::Skill.load`](https://r.uby.dev/api-docs/llm.rb/LLM/Skill.html#load-class_method)
  now accepts a path to a markdown file in addition to a directory path.
  When given a file path, the file is read directly instead of looking for
  a `SKILL.md` inside a directory. This makes it possible to load a single
  markdown file as a skill without placing it in a dedicated directory.

* **extend with `all` keyword for loading the full tool registry** <br>
  `LLM::Skill` now supports `tools: all` (or `tools: "*"`) in the frontmatter
  to load all tools from the global
  [`LLM::Tool.registry`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html#registry-class_method).
  Previously, the `tools:` frontmatter only accepted `inherit`, an array of tool
  names, or nothing. The new `all` keyword makes it possible to give a skill
  access to every registered tool without listing them individually.

### Tools

* **add `LLM::Tool::Ruby` for executing Ruby code in a subprocess** <br>
  [`LLM::Tool::Ruby`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Ruby.html)
  is a new built-in tool that runs a string of Ruby code in a separate
  Ruby process with a configurable timeout (default 15s). The code runs
  in an isolated address space unaware of its parent, making it useful
  for safe(ish) dynamic code execution. It must be required explicitly
  with `require "llm/tools/ruby"` and requires the `test-cmd.rb` gem.

* **rename `LLM::Tool::SwapText` to `LLM::Tool::EditFile`** <br>
  The `SwapText` tool has been renamed to
  [`LLM::Tool::EditFile`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/EditFile.html)
  to better match the naming of sibling tools (`ReadFile`, `WriteFile`).
  The old `require "llm/tools/swap_text"` path no longer exists; use
  `require "llm/tools/edit-file"` instead.

### Tracer

* **add `LLM::Tracer::PrettyLogger` for human-readable tracing** <br>
  [`LLM::Tracer::PrettyLogger`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer/PrettyLogger.html)
  is a new tracer that writes human-readable request and tool-call logs to a
  console or file. Unlike the structured JSON output of
  `LLM::Tracer::Logger`, the pretty logger emits single-line entries with
  inline context, making it easier to follow agent activity at a glance.
  It writes to `$stderr` by default and accepts an `io:` option for file
  output.

### Repl

* **rename `LLM::Repl::Transcript` to `LLM::Repl::Buffer`** <br>
  `LLM::Repl::Transcript` has been renamed to
  [`LLM::Repl::Buffer`](https://r.uby.dev/api-docs/llm.rb/LLM/Repl/Buffer.html)
  to better reflect its role as a conversation state manager. The old
  `start` and `finish` methods have been renamed to `open` and `close`
  respectively. The public accessor on
  [`LLM::Repl`](https://r.uby.dev/api-docs/llm.rb/LLM/Repl.html) has been
  renamed from `transcript` to `buffer`.

* **add `write_message` for formatted message writing** <br>
  [`LLM::Repl::Buffer#write_message`](https://r.uby.dev/api-docs/llm.rb/LLM/Repl/Buffer.html#write_message-instance_method)
  and
  [`LLM::Repl#write_message`](https://r.uby.dev/api-docs/llm.rb/LLM/Repl.html#write_message-instance_method)
  provide a convenience method that takes a username and content string,
  formatting the output with a bold `user:` label and a trailing newline.
  This is simpler than the equivalent sequence of `write` calls.

* **add `Command#write_message` and refactor `Command#write`** <br>
  [`LLM::Command#write_message`](https://r.uby.dev/api-docs/llm.rb/LLM/Repl/Command.html#write_message-instance_method)
  provides a convenience method that takes a username and content string,
  matching the same interface on `LLM::Repl` and `LLM::Buffer`. The
  `Command#write` method is now implemented on top of `write_message`,
  always prefixing output with `command(<name>): `. The `who:` keyword
  argument previously accepted by `write` has been removed; use
  `write_message` instead.

* **display pre-existing agent messages when the repl starts** <br>
  When
  [`LLM::Agent#repl`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#repl-instance_method)
  starts, any messages already in the agent's buffer are now rendered
  in the REPL window. Previously the REPL started with an empty
  transcript even when the agent carried prior conversation history,
  making it harder to resume a session. Tool-call and tool-return
  messages are skipped to avoid visual noise.

### CLI

* **add `bin/llm.rb` for launching the REPL from the command line** <br>
  A new executable script (`bin/llm.rb`) provides a convenient way to start
  an interactive REPL session directly from the terminal. It auto-detects
  the provider from environment variables like `OPENAI_API_KEY`, supports
  a `-p PROVIDER` flag for explicit provider selection, a `-t` flag for
  temporary (non-persistent) sessions, and `-h` for help. Sessions are
  automatically saved to `~/.llm.rb/` by default.

### Fix

* **agent: fix `path` restore on first run** <br>
  Fix a bug where [`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html)
  called `@ctx.restore(path:)` even when the path's file did not exist.
  The fix checks `File.readable?(@path)` before attempting to restore,
  so the agent starts with a blank conversation on first use instead of
  failing with a file-not-found error.

* **tools: re-raise `LLM::Interrupt` to abort the turn** <br>
  [`LLM::Tool::Git`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Git.html),
  [`LLM::Tool::Mkdir`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Mkdir.html),
  [`LLM::Tool::Rg`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Rg.html),
  [`LLM::Tool::Ruby`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Ruby.html),
  and
  [`LLM::Tool::Shell`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Shell.html)
  now re-raise `LLM::Interrupt` after killing their running command. The
  previous behavior rescued the interrupt and killed the child process but
  let the turn continue, which meant a cancelled tool call did not abort
  the conversation turn. Re-raising ensures the entire turn is interrupted.

* **tools: rescue `LLM::Interrupt` in shell-based tools** <br>
  [`LLM::Tool::Shell`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Shell.html),
  [`LLM::Tool::Git`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Git.html),
  [`LLM::Tool::Mkdir`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Mkdir.html),
  and
  [`LLM::Tool::Rg`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Rg.html)
  now rescue `LLM::Interrupt` and kill their running command, preventing
  orphaned child processes when a tool is interrupted during execution.

* **agent: fix default name derivation** <br>
  Fix a bug where `LLM::Agent` used without a subclass derived its default
  name as `"l-lm-agent"` instead of `"agent"`. The fix replaces the
  regex-based parameterization with a pattern that correctly handles
  single-word class names and multi-word namespaced names.

* **function: `#params` always returns an `LLM::Object`** <br>
  [`LLM::Function#params`](https://r.uby.dev/api-docs/llm.rb/LLM/Function.html#params-instance_method)
  now always returns an `LLM::Object` representing the function's parameter
  schema. Previously it returned `nil` when a function defined no parameters,
  forcing every caller to guard against `nil`. All provider adapters now use
  `fn.params.to_h` instead of `fn.params || {type: "object", properties: {}}`.

## v13.0.0

v13.0.0 relicenses the project under the MIT license, replacing
the Business Source License that was introduced in v12.0.0. No
commercial license is needed. Commercial, personal, educational, and
all other uses are now permitted under the standard MIT terms.

Seven breaking changes. Concurrency strategies have been renamed
(`:call` → `:sequential`, `:task` → `:async`), `spawn` is now
`task`, and the `:async` strategy has been rebuilt from the ground
up. It no longer blocks and now supports interruption. The compactor
has been refactored into pluggable strategies. Interruption is now
reliable across all six concurrency backends. The `functions` and
`functions?` methods have been renamed to `pending_functions` and
`pending_functions?`.

### Migration from v12.6.0

| Old | New |
|-----|-----|
| `fn.spawn(:call)` | `fn.task(:sequential)` |
| `fn.spawn(:task)` | `fn.task(:async)` |
| `ctx.wait(:call)` | `ctx.wait(:sequential)` |
| `agent.concurrency :task` | `agent.concurrency :async` |
| `LLM::Function::FiberGroup` | `LLM::Function::Fiber::Group` |
| `LLM::Function::CallGroup` | `LLM::Function::Sequential::Group` |
| `LLM::Function::TaskGroup` | `LLM::Function::Async::Group` |
| `Compactor.new(model:, token_threshold:)` | `Compactor::Truncate.new(ctx)` |
| `on_compaction(ctx, compactor)` | `on_compaction(compactor)` |
| `ctx.functions` / `ctx.functions?` | `ctx.pending_functions` / `ctx.pending_functions?` |
| `agent.functions` / `agent.functions?` | `agent.pending_functions` / `agent.pending_functions?` |

### Breaking

* **rename `LLM::Function#spawn` as `LLM::Function#task`** <br>
  [`LLM::Function#task`](https://r.uby.dev/api-docs/llm.rb/LLM/Function.html#task-instance_method)
  (previously `spawn`) now consistently returns a
  [`LLM::Function::Task`](https://r.uby.dev/api-docs/llm.rb/LLM/Function/Task.html)
  object that can be spawned, waited on, and passed to
  [`LLM::Function::Group`](https://r.uby.dev/api-docs/llm.rb/LLM/Function/Group.html).
  The old implementation alternated between spawning immediately or
  returning a raw thread or fiber.

* **rename concurrency strategies (`:call` → `:sequential`,**
  **`:task` → `:async`)** <br>
  The `:call` concurrency strategy is now `:sequential`, and the `:task`
  strategy is now `:async`.
  [`LLM::Agent.concurrency`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#concurrency-class_method),
  [`LLM::Context#wait`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#wait-instance_method),
  `LLM::Function::Array#task`, and
  [`LLM::Function#task`](https://r.uby.dev/api-docs/llm.rb/LLM/Function.html#task-instance_method)
  all accept the new names. The old names raise `ArgumentError`.

* **rename group classes** <br>
  Group classes have been moved into their strategy's namespace:
  `FiberGroup` → `Fiber::Group`, `ThreadGroup` → `Thread::Group`,
  `CallGroup` → `Sequential::Group`, `TaskGroup` → `Async::Group`,
  `Fork::Group` → `Fork::Group`, `Ractor::Group` → `Ractor::Group`.

* **repurpose `LLM::Function::Task` as a task interface superclass** <br>
  `LLM::Function::Task` has been repurposed from a general-purpose class
  that tried to support multiple concurrency strategies into an abstract
  base class that defines the task interface. Individual strategies
  (`Sequential::Task`, `Thread::Task`, `Fiber::Task`, `Async::Task`,
  `Fork::Task`, `Ractor::Task`) now subclass it and implement
  `spawn`, `alive?`, `interrupt!`, and `wait`.

* **fix `:async` concurrency (now backed by a managed**
  **`LLM::Function::Async::Reactor` on a background thread)** <br>
  The `:async` strategy previously used `Async {}` which blocked the
  caller until all tasks completed and did not support interruption.
  The fix replaces it with a per-turn
  `LLM::Function::Async::Reactor` on a background thread. Work is
  submitted via `submit(&block)` and consumed by the reactor's event
  loop through a thread-safe `Queue`. `Async::Group` manages the
  reactor lifecycle and spawns tasks lazily on `wait`.
  <br><br>
  Interruption pushes [`LLM::Interrupt`](https://r.uby.dev/api-docs/llm.rb/LLM/Interrupt.html)
  to the task's result queue instead of using `Fiber#raise`, and
  results are bridged back to the caller through a second `Queue`.
  This work drove the broader refactor of strategy naming, the
  spawn/wait split, and the `Task` superclass. The `:async` strategy
  needed the same interface the other strategies already had.

* **compactor: refactor to strategy-based interface** <br>
  [`LLM::Compactor`](https://r.uby.dev/api-docs/llm.rb/LLM/Compactor.html)
  has been refactored from a single class that performed LLM-based
  summarization into a strategy-based superclass. Each subclass
  implements a different compaction strategy via `call(**opts)`. The old
  summarization approach (using `model:`, `token_threshold:`,
  `message_threshold:`, and `retention_window:` options) has been removed.
  The built-in
  [`LLM::Compactor::Truncate`](https://r.uby.dev/api-docs/llm.rb/LLM/Compactor/Truncate.html)
  strategy drops the oldest messages when the conversation exceeds a
  configured size.

* **rename `LLM::Context#{functions,functions?}` and `LLM::Agent#{functions,functions?}`** <br>
  [`LLM::Context#functions`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#functions-instance_method)
  and
  [`LLM::Context#functions?`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#functions%3F-instance_method)
  have been renamed to
  [`LLM::Context#pending_functions`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#pending_functions-instance_method)
  and
  [`LLM::Context#pending_functions?`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#pending_functions%3F-instance_method)
  respectively. The same rename applies to
  [`LLM::Agent#functions`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#functions-instance_method)
  (now
  [`LLM::Agent#pending_functions`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#pending_functions-instance_method)).
  The `pending_functions` name was already available as an alias in
  v12.5.0; this change removes the old `functions` name entirely.

### Core

* **extend `LLM.require` with an optional version argument** <br>
  `LLM.require` now accepts a second `version` parameter that is passed
  to `Kernel#gem` before loading, enabling version constraints for
  optional runtime dependencies. For example,
  `LLM.require "test-cmd.rb", "~> 1.1"` ensures a minimum gem version
  is available. This is used internally by the `Git`, `Rg`, `Mkdir`,
  and `Shell` tools to enforce compatibility with the `test-cmd.rb` gem.

### Compactor

* **add `Truncate` strategy for dropping oldest messages** <br>
  [`LLM::Compactor::Truncate`](https://r.uby.dev/api-docs/llm.rb/LLM/Compactor/Truncate.html)
  is a new built-in compaction strategy that drops the oldest messages
  when the conversation exceeds a configured size. It preserves tool
  call/return pairs so the algorithm never breaks in the middle of a
  sequence. Configured with `keep:` (default 64), it emits the standard
  `on_compaction` and `on_compaction_finish`
  [`LLM::Stream`](https://r.uby.dev/api-docs/llm.rb/LLM/Stream.html)
  lifecycle callbacks. No LLM call is made; the strategy is purely
  lossy but fast and requires no network.

* **raise when given an unparseable `keep:` value** <br>
  `LLM::Compactor::Truncate` now raises `ArgumentError` when the `keep:`
  parameter cannot be parsed as an integer or percentage string, instead
  of failing with an obscure error later during execution.

* **accept percentage string for the `keep:` parameter** <br>
  `LLM::Compactor::Truncate#call` now accepts a percentage string such
  as `"80%"` for the `keep:` parameter, which keeps approximately 80%
  of the most recent messages. Integer values continue to work as
  before. This makes it easy to trim proportionally rather than to an
  absolute number of messages.

* **add `Null` strategy for no-op compaction** <br>
  [`LLM::Compactor::Null`](https://r.uby.dev/api-docs/llm.rb/LLM/Compactor/Null.html)
  is a new built-in compaction strategy that does nothing. It is used as
  the default compactor when no strategy is configured on a context,
  ensuring the compactor interface is always present without requiring a
  separate nil check.

* **accept both `LLM::Agent` and `LLM::Context`** <br>
  [`LLM::Compactor#initialize`](https://r.uby.dev/api-docs/llm.rb/LLM/Compactor.html#initialize-instance_method)
  now accepts both `LLM::Agent` and `LLM::Context` instances. When given
  an agent, the internal context is unwrapped automatically, making the
  compactor API more flexible when working with agents.

#### Context integration

* **accept `compactor` and `compactor_options` parameters** <br>
  [`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html)
  now accepts `compactor:` (a compactor class defaulting to
  [`LLM::Compactor::Null`](https://r.uby.dev/api-docs/llm.rb/LLM/Compactor/Null.html))
  and `compactor_options:` (a hash of options forwarded to the
  compactor's `call` method) parameters. The compactor is automatically
  invoked at the beginning of each `talk` turn. The previous `compactor=`
  setter has been removed in favour of constructor-driven configuration.

* **`on_compaction` and `on_compaction_finish` receive a single argument** <br>
  [`LLM::Stream#on_compaction`](https://r.uby.dev/api-docs/llm.rb/LLM/Stream.html#on_compaction-instance_method)
  and
  [`LLM::Stream#on_compaction_finish`](https://r.uby.dev/api-docs/llm.rb/LLM/Stream.html#on_compaction_finish-instance_method)
  now accept a single argument (the compactor instance) instead of two
  arguments (context and compactor). The context is still available via
  `LLM::Compactor#ctx`, so access to the context is not lost. This
  simplifies the callback interface for compaction lifecycle observers.

### Tools

* **add `LLM::Tool::Utils` module for shared command execution logic** <br>
  A new
  [`LLM::Tool::Utils`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Utils.html)
  module provides shared `wait(command:, timeout:)` and `now` helper
  methods for tools that execute commands. Tools that include `Utils` can
  wait on a running command and automatically kill it when it exceeds the
  configured timeout, using `Process.clock_gettime` with `CLOCK_MONOTONIC`
  for precise timing. The module is used by both the `Shell` and `Rg`
  tools internally.

* **shell: add `timeout` parameter for command execution deadlines** <br>
  The
  [`LLM::Tool::Shell`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Shell.html)
  tool now accepts a `timeout` parameter (default 60s) that automatically
  kills commands exceeding the specified time limit, preventing hung
  processes from blocking the agent indefinitely.

* **rg: add `timeout` parameter for search execution deadlines** <br>
  The
  [`LLM::Tool::Rg`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Rg.html)
  tool now accepts a `timeout` parameter (default 5s) that automatically
  kills search commands exceeding the specified time limit, preventing
  long-running searches from blocking the agent indefinitely.

* **git: add `timeout` parameter for command execution deadlines** <br>
  The
  [`LLM::Tool::Git`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Git.html)
  tool now accepts a `timeout` parameter (default 5s) that automatically
  kills git commands exceeding the specified time limit, preventing hung
  processes from blocking the agent indefinitely.

### Schema

* **properties are now ordered and support indifferent access** <br>
  [`LLM::Schema::Leaf`](https://r.uby.dev/api-docs/llm.rb/LLM/Schema/Leaf.html)
  tracks property definition order in a new `index` attribute, matching
  the convention already used by
  [`LLM::Command::Parameter`](https://r.uby.dev/api-docs/llm.rb/LLM/Command/Parameter.html).
  Internally, `@properties` is stored as an
  [`LLM::Object`](https://r.uby.dev/api-docs/llm.rb/LLM/Object.html)
  instead of a plain `Hash`, so lookups with both string and symbol keys
  work.

### Buffer

* **more array-like message management** <br>
  [`LLM::Buffer`](https://r.uby.dev/api-docs/llm.rb/LLM/Buffer.html)
  now exposes `first`, `reject!`, `select!`, `shift`, `clear`, `drop`,
  `take`, and `reverse`, making it easier to query and mutate
  `LLM::Context#messages` like an ordinary Array. `reject!` is aliased
  as `delete_if` for familiarity.

* **`last(nil)` no longer returns the last message** <br>
  `LLM::Buffer#last` now uses an internal `UNDEFINED` sentinel to
  distinguish between no argument (`last` returns the last message)
  and `nil` (`last(nil)` is treated as an argument). Previously `nil`
  was indistinguishable from no argument.

### Function

* **consolidate `call` and `call!` into one method** <br>
  The private `call!` method has been merged into the public
  [`LLM::Function#call`](https://r.uby.dev/api-docs/llm.rb/LLM/Function.html#call-instance_method).
  The separate `call!` method existed for tracer-scoping logic now
  handled directly inside `call`. All internal call sites now use
  `function.call` instead of `function.call!`.

* **add `LLM::Function::Group` as an abstract base class** <br>
  A new abstract base class
  ([`LLM::Function::Group`](https://r.uby.dev/api-docs/llm.rb/LLM/Function/Group.html))
  defines the interface that all concurrency strategy groups must
  implement: `alive?`, `interrupt!`, and `wait`. Each strategy group
  (`Sequential::Group`, `Thread::Group`, `Fiber::Group`,
  `Async::Group`, `Fork::Group`, `Ractor::Group`) now subclasses
  this base.

* **split `spawn` and `wait` across all strategies** <br>
  `spawn` now starts execution without blocking, and `wait` collects
  the result. `on_tool_start` moved into each task's `spawn` so the
  tracer span covers execution rather than construction. Each task and
  group now exposes a public `spawn` method alongside the existing
  `wait`/`value` methods.

* **spawn tasks lazily in `Group#wait`** <br>
  All concurrency strategy groups (Fiber::Group, Fork::Group,
  Ractor::Group, Thread::Group) now automatically spawn their tasks
  when `wait` is called if they haven't been spawned yet, matching
  the existing `Async::Group` behavior. This makes the spawn/wait
  contract consistent across all six concurrency backends.

### Agent

* **add `name` class DSL and instance method** <br>
  [`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html) now
  has a `name` class DSL (`name "admin"`) and a corresponding `#name`
  instance method. The name is resolved through the same lazy-resolution
  path as other agent attributes. It can be set via
  `LLM::Agent.set(name: ...)`, `LLM::Agent.new(name: ...)`, or the class
  DSL. When no name is given, a default is derived from the class name
  (e.g., `SystemAdmin` becomes `system-admin`). The REPL uses the name
  as the prompt label and transcript prefix, making it easier to
  distinguish multiple sessions.

### REPL

* **agent identity in the prompt** <br>
  [`LLM::Agent#repl`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#repl-instance_method)
  and
  [`LLM::Repl.new`](https://r.uby.dev/api-docs/llm.rb/LLM/Repl.html#initialize-instance_method)
  accept a `name:` parameter (defaulting to `LLM::Agent#name`) that sets
  the input prompt to `provider(name)> ` and labels transcript messages
  with the agent's name instead of a hardcoded `agent:`. Useful when
  running multiple sessions.

* **`/compact` command** <br>
  New built-in `/compact` command frees context window space by dropping
  the oldest messages via
  [`LLM::Compactor::Truncate`](https://r.uby.dev/api-docs/llm.rb/LLM/Compactor/Truncate.html).
  Supports both integer (`/compact 32`) and percentage (`/compact 75%`)
  arguments. Defaults to keeping the last 128 messages.

* **tab-completion for `/` commands** <br>
  Pressing Tab on an input line starting with `/` autocompletes the
  command name. Repeated Tab presses cycle through matching commands.
  Powered by
  [`LLM::Command.complete(str)`](https://r.uby.dev/api-docs/llm.rb/LLM/Command.html#complete-class_method)
  which is available outside the REPL too.

* **command system enhancements** <br>
  Commands can set parameter defaults in their `call` method signature
  (e.g., `def call(n: 128)`). Aliases like `/quit` now inherit their
  parent's description and parameters. Commands also have access to
  the active `agent` and `repl` via public readers.

* **tool argument sorting** <br>
  Tool parameters in the status bar are now displayed in definition
  order (using the new `index` attribute), regardless of the order
  the model returns them.

* **expanded markdown rendering** <br>
  The curses-based markdown renderer now handles lists (`<ul>`, `<ol>`),
  blockquotes, horizontal rules, hyperlinks (underline), images
  (`[image: alt text]`), and tables (aligned columns).

* **input improvements** <br>
  Ctrl+P and Ctrl+N walk through conversation history (user messages
  only, managed by
  [`LLM::Repl::Walker`](https://r.uby.dev/api-docs/llm.rb/LLM/Repl/Walker.html)).
  Page Up/Down scroll the transcript by a page. ENTER and BACKSPACE are
  now mapped to raw character codes from `Curses.getch` instead of
  `Curses::Key` constants.

### Object

* **preserve the original key name in `KeyError` messages** <br>
  `LLM::Object#fetch` now preserves the original key name when a key
  is not found, instead of raising `KeyError` with `key not found: nil`.
  The previous behavior occurred when the given key was not found in
  the stored hash, causing internal lookup to return `nil` and lose
  the original key reference.

### Registry

* **refresh model metadata across providers** <br>
  Update `data/*.json` files with current provider model listings and
  pricing. Mark several DeepInfra models as deprecated (`meta-llama/
  Meta-Llama-3.1-8B-Instruct`, `Qwen/Qwen1.5-110B-Chat`, and
  `mistralai/Mixtral-8x7B-Instruct-v0.1`). Correct xAI cache-read
  pricing from $0.50 to $0.30 per million input tokens.

### Fix

* **agent: fix default name resolution when name is not explicitly set** <br>
  Fix a bug where `LLM::Agent` derived its default name from
  `self.class` instead of `self`, causing the name to be `"class"`
  instead of a parameterized version of the actual class name
  (e.g., `"system-admin"` for `SystemAdmin`). The fix uses `self`
  directly, which correctly resolves the class name at the instance
  level.

* **function: make Fork::Task and Ractor::Task inherit LLM::Function::Task** <br>
  `LLM::Function::Fork::Task` and `LLM::Function::Ractor::Task` now
  explicitly subclass `LLM::Function::Task` and accept an options hash
  as their second argument, matching the constructor signature used
  by the other four task classes. The interface was already compatible
  but the inheritance was missing by mistake. It is now consistent across
  all six concurrency backends.

* **google: fix `stream` parameter leakage that broke the provider** <br>
  Fix a bug in the Google provider where `stream: stream.enabled?` was
  being merged into request parameters, causing API-level errors. The
  Google provider does not use a `stream` parameter. Streaming is
  controlled via the URL path (`streamGenerateContent` vs
  `generateContent`). The fix removes the leaked parameter and correctly
  routes streaming requests through the appropriate path.

* **fork: fix deadlock on xchan.rb channel** <br>
  Fix a deadlock in the `:fork` concurrency strategy where both the
  writer and reader could get stuck on the xchan channel, preventing the
  reader from draining the channel. The deadlock surfaced as an errno
  failure, especially with large tool returns. The fix requires xchan.rb
  v0.22.0 and uses the `SOCK_STREAM` socket type for communicating a
  tool's return value.

## v12.6.0

Changes since `v12.5.1`.

This release adds bulk defaults for tools and agents: `LLM::Tool.defaults`
for setting parameter defaults and `LLM::Agent.set` for mass-assigning
class-level defaults, both mirrored on ActiveRecord and Sequel agent models.

It also makes `LLM::Interrupt` reliable across every concurrency strategy
(:thread, :call, :fiber, :task, :fork, and :ractor) so tool cancellation
works consistently regardless of execution backend, and fixes a stale fiber
reference in `LLM::Context#talk` that could prevent interruption after a
prior call.

### Add

* **tool: add `defaults` method for setting parameter defaults** <br>
  Add `LLM::Tool.defaults(properties)` for bulk-setting default values
  on tool parameters, matching the same interface as `LLM::Schema.defaults`.
  Each key maps to a parameter name; unknown keys raise `KeyError`.

* **agent: add `set` method for bulk-assigning class-level defaults** <br>
  Add `LLM::Agent.set(properties)` for mass-assigning agent defaults
  from a Hash. Each key maps to a class-level accessor; unknown keys
  raise `KeyError`.

* **active_record: expose `set` on `acts_as_agent` models** <br>
  ActiveRecord models using `acts_as_agent` can call `set` to
  bulk-assign agent class-level defaults.

* **sequel: expose `set` on `plugin :agent` models** <br>
  Sequel models using `plugin :agent` can call `set` to bulk-assign
  agent class-level defaults.

### Fix

* **function: raise `LLM::Interrupt` on thread where tool is running** <br>
  On cancel, `LLM::Interrupt` is now raised on the thread that is
  running a tool. The tool can rescue `LLM::Interrupt` and gracefully
  terminate (e.g., clean up resources). The previous approach used
  `Thread#interrupt` which was less reliable. It did not interrupt a
  sleeping thread.

* **function: suppress thread exception reporting in `:thread` concurrency** <br>
  Threads spawned by the `:thread` concurrency strategy now have
  `report_on_exception` set to `false`, preventing noisy exception
  messages from appearing on stderr when a thread is interrupted
  during tool execution.

* **context: clear `@owner` after `talk` completes** <br>
  `LLM::Context#talk` now clears the `@owner` reference in an
  `ensure` block after the method completes, so `interrupt!` does
  not attempt to interrupt a stale fiber reference from a prior
  call.

* **function: raise `LLM::Interrupt` on thread waiting in `CallGroup#wait`** <br>
  When using `ctx.wait(:call)`, `LLM::Interrupt` is now raised on the
  thread executing the sequential tool wait. `CallGroup#wait` tracks the
  active thread and `interrupt!` raises `LLM::Interrupt` on it, enabling
  interruption of the `:call` concurrency strategy just like the existing
  `:thread` strategy.

* **function: raise `LLM::Interrupt` on fiber-backed tool tasks** <br>
  `LLM::Interrupt` is now raised on the active fiber via `Fiber#raise`
  when interrupting `:fiber`-concurrency tools.
  <br><br>
  `Task#interrupt!` now dispatches by task type: `Thread#raise` for
  threads, `Fiber#raise` for fibers. Making interruption reliable
  across all concurrency strategies.

* **function: raise `LLM::Interrupt` on fork-backed tool tasks** <br>
  `LLM::Interrupt` is now raised on the main thread of a fork child
  process via `Thread.main.raise(LLM::Interrupt)` when interrupting
  `:fork`-concurrency tools, and the fork `Task#wait` re-raises the
  interrupt on the parent side. Making interruption reliable across
  all concurrency strategies including `:fork`.

* **function: raise `LLM::Interrupt` on `Async::Task`-backed tool tasks** <br>
  `LLM::Interrupt` is now raised on the underlying fiber of an
  `Async::Task` via `Fiber#raise` when interrupting `:task`-concurrency
  tools. `Task#interrupt!` now detects `Async::Task` instances and
  dispatches to `Fiber#raise`, extending reliable interruption to the
  `:task` concurrency strategy under the Async runtime.

* **function: raise `LLM::Interrupt` on ractor-backed tool tasks** <br>
  `LLM::Interrupt` is now raised on the main thread inside a ractor
  via `Thread.main.raise(LLM::Interrupt)` when interrupting
  `:ractor`-concurrency tools. A listener thread inside the tool
  ractor waits for an interrupt message via `Ractor.receive` and
  raises `LLM::Interrupt` on the ractor's main thread.
  <br><br>
  `Task#interrupt!` delegates to the mailbox to send the interrupt
  message. Extending reliable interruption to the `:ractor`
  concurrency strategy.

## v12.5.1

Changes since `v12.5.0`.

This release reverts the global `LLM::Function` registry fallback for tool
resolution that was added in v12.5.0.

### Change

* **function: remove the global registry fallback for tool resolution** <br>
  Remove the `LLM::Function.find_by_name` fallback that was added in
  v12.5.0 as an intermediate step between available-tools lookup and
  raising `LLM::NoSuchToolError`. Tool calls not found in the available
  tools list now go directly to `function_missing` (which raises
  `LLM::NoSuchToolError`) without first checking the global
  `LLM::Function` registry.

## v12.5.0

Changes since `v12.4.0`.

This release extends the REPL command system with typed parameters, a
built-in `/help` command, command aliases (`/quit`), and cancellation
via the 'Esc' key.

The default HTTP timeout is increased to 15 minutes (900s) to better
accommodate reasoning models and large structured outputs.
`LLM::Agent#deserialize` and `LLM::Agent#restore` now return `self` for
method chaining, and `LLM::Buffer#pop` is added for tail-end message
removal.

Tool resolution gains a fallback to the global `LLM::Function` registry
before raising `LLM::NoSuchToolError`, and `pending_functions` aliases
are added on both contexts and agents for a consistent interface.

Several REPL bugs are fixed including parameter state leakage across
turns and invalid tool-call error routing.

Model metadata is refreshed across all providers with new Anthropic,
OpenAI, Google, DeepInfra, DeepSeek, and xAI model entries.

### Add

#### Buffer & function internals

* **buffer: add `LLM::Buffer#pop`** <br>
  Add `LLM::Buffer#pop` for removing the last message from the tail
  of the buffer, complementing the existing `#<<` and array-style
  message management.

* **function: add registry fallback for tool resolution** <br>
  When resolving tool calls from a message, if the tool is not found
  in the available tools list, it now also looks up the global
  `LLM::Function` registry via `LLM::Function.find_by_name` before
  creating a placeholder function. This improves tool resolution for
  tools that are registered globally but not passed directly through
  the request tool set.

#### Consistent `pending_functions` aliases

* **context: alias `LLM::Context#functions` as `LLM::Context#pending_functions`** <br>
  Add `LLM::Context#pending_functions` as an alias for `LLM::Context#functions`,
  so callers that prefer the more descriptive `pending_functions` name can use
  it instead of `functions` when checking for unresolved tool work.

* **agent: alias `LLM::Agent#functions` as `LLM::Agent#pending_functions`** <br>
  Add `LLM::Agent#pending_functions` as an alias for `LLM::Agent#functions`,
  matching the same alias on `LLM::Context`, so callers have a consistent
  `pending_functions` interface across both contexts and agents.

#### REPL command system

* **repl: extend command system with parameter support** <br>
  Commands can now declare typed parameters using the `parameter`
  DSL, modelled after `LLM::Tool` and `LLM::Schema` conventions.
  Parameters can be marked as required with `required %i[...]`,
  and values are type-checked before being passed to `call`.
  Argument parsing is handled by the repl: arguments are split
  from the input string and assigned to parameters by position.

  ```ruby
  class Greeter < LLM::Command
    name "greet"
    description "Greets the given name"
    parameter :name, String, "The person's name"
    required %i[name]

    def call(name:)
      write("Welcome #{name}!\n")
    end
  end
  ```

* **repl: add `help` command** <br>
  Add `LLM::Repl::Help` as a new built-in command, registered
  automatically via the command registry. Typing `/help` shows
  the `help` command's own name, description, and parameters,
  while `/help <name>` shows details for a specific command,
  including its parameters and whether each is required or
  optional. Unknown command names produce an error message.

  ```ruby
  class Help < Command
    name "help"
    description "show help for a given command"
    parameter :name, String, "The name of a command"

    def call(name: nil)
      if name.nil?
        write("\n#{self.class.help}\n\n")
      elsif command = LLM::Command.find_by(name:)
        write("\n#{command.help}\n\n")
      else
        write "\nNo help for #{name} was found" \
              "\nThat command doesn't exist.\n\n"
      end
    end
  end
  ```

* **repl: add support for command aliases** <br>
  Commands can now be aliased by creating a subclass of another
  command (with `LLM::Command` as an indirect ancestor). The
  first alias introduced is `/quit` as an alias of `/exit`.

  ```ruby
  class Quit < Command::Exit
    name "quit"
  end
  ```

* **repl: add `Command::Parameter#optional?`** <br>
  Parameters now expose an `#optional?` method that returns `true`
  when a parameter has not been marked as required, making it
  possible to query parameter optionality programmatically.

* **repl: add `LLM::Repl::Command#write`** <br>
  Commands can now write output to the transcript via the `write`
  method. Commands also receive a reference to the active repl
  through their `#initialize` method, making it possible to
  interact with the repl window from within a command.

* **repl: display command errors in the curses UI** <br>
  Commands invoked with too few arguments now display an error
  message: `command(<name>): too few arguments`. Displayed directly in
  the curses transcript area, giving immediate feedback instead
  of silently failing.

* **repl: add `LLM::Command` convenience constant** <br>
  Add `LLM::Command = LLM::Repl::Command` as a shorter alias,
  available once `"llm/repl"` is required.

#### Misc

* **repl: implement cancellation with the 'Esc' key** <br>
  The curses-based REPL now supports cancelling an active model
  request by pressing the 'Esc' key. When a request is in progress,
  the status line shows `thinking • Esc to cancel`, and pressing
  Esc calls `LLM::Agent#cancel!` to interrupt the request. The
  transcript displays `request cancelled!` to confirm the
  cancellation.

### Change

#### Misc

* **provider: increase default timeout to 900s** <br>
  The default HTTP timeout for all providers has been increased from
  180 to 900 seconds (15 minutes) to better accommodate long-running
  requests such as reasoning models and large structured outputs.

* **agent: `deserialize` and `restore` return `self`** <br>
  `LLM::Agent#deserialize` and `LLM::Agent#restore` now return `self`
  (the agent instance) instead of forwarding the context's return
  value, enabling method chaining after restoring agent state.

* **context: discard all messages from a cancelled turn** <br>
  When `LLM::Context#cancel!` is called, all messages added during
  that turn are now discarded via `Buffer#slice!`, preventing edge
  cases where dangling tool calls between turns caused repeated
  cancellation loops. The `#repair!` method now handles tool call
  cancellations on the next turn instead of mutating the conversation
  buffer directly at cancellation time.

* **stream: drop the `error` argument from `on_tool_call`** <br>
  The `on_tool_call` callback no longer accepts an `error` argument.
  Previously, stream parsers passed both a tool and an optional error,
  requiring boilerplate like `if error; queue << error; end` in every
  callback. Error handling is now pushed directly onto the stream queue
  inside each provider's stream parser, so `on_tool_call(tool)` is the
  only signature. The REPL stream and base `LLM::Stream` class have
  been updated accordingly.

#### REPL internals

* **repl: pass the repl instance to command constructors** <br>
  `LLM::Repl::Command` subclasses now receive the active repl
  instance via `initialize(repl)`, enabling commands to write
  to the transcript and interact with the repl window.

* **repl: `Command#write` prefixes messages with the command name** <br>
  The `#write` method now prefixes output with `command(<name>): `
  so command messages are consistent with the `user:` and `agent:`
  labels in the transcript. The prefix can be customised with the
  `who:` keyword argument, or set to `who: nil` to disable it
  entirely.

### Fix

#### Misc

* **function: avoid silent skip of tools not found in available tools** <br>
  When a model calls a tool that is not present in the available tools
  list, instead of silently skipping the tool call (via `next`), a
  `LLM::NoSuchToolError` is now raised so the model receives feedback
  about the invalid tool call and can correct course.
  <br><br>
  An additional fallback to the global `LLM::Function` registry is
  tried before raising, so globally registered tools are still
  resolved even when not in the per-request tool set.

#### REPL bugs

* **repl: don't persist parameter state between turns** <br>
  Parameter state (such as `Parameter#value`) was leaking across
  turns because the same parameter objects were being mutated
  in place. A duplicate set of parameters is now created for each
  turn, keeping the original parameter definitions intact and
  preventing stale state from carrying over.

* **repl: reply with error when given an invalid tool** <br>
  When the model tries to call a tool that does not exist, the
  error is now pushed onto the stream queue so the model can
  see the error and correct course, instead of silently dropping
  the invalid tool call and leaving it to `Context#repair` to
  remove it from history.

* **repl: fix save of initial runtime state** <br>
  Fix a bug in `LLM::Repl#configure` where a non-existent path
  argument was treated as no path at all, preventing the initial
  runtime state from being saved after the first turn. The correct
  behavior is to create the file so it can be written to after
  the first turn completes.

### Refresh

* **Refresh model metadata across all providers** <br>
  Update model listings, pricing, capabilities, reasoning options,
  modality support, context limits, and release dates across all
  provider registries (Anthropic, AWS Bedrock, DeepInfra, DeepSeek,
  Google, Mistral, OpenAI, xAI, and ZAI). Notable changes include
  Anthropic claude-opus-4-8 and claude-sonnet-4-6 additions with
  effort-based reasoning, OpenAI gpt-5.6-sol/terra/luna and
  gpt-5-codex additions, Google gemini-3-pro-preview and
  gemini-3-flash-preview additions, DeepInfra Qwen3.5 and DeepSeek
  V4 model additions, and updated xAI Grok model entries.

## v12.4.0

Changes since `v12.3.1`.

This release brings major improvements to the curses-based REPL
(`LLM::Agent#repl`). The REPL now supports saving and restoring runtime
state across sessions, automatic paste-mode detection for fast bulk input,
a command system foundation with the `/exit` command, and several new
keybindings (Ctrl+F, Ctrl+K, Ctrl+Y). Tool calls are rendered with a
compact function-call syntax in the status bar.

Two new built-in tools: `LLM::Tool::Ls` and `LLM::Tool::Which` are
available as opt-in additions for file listing and executable lookup.

Model metadata has been refreshed across providers, the REPL loop
internals have been refactored to use `catch`/`throw` for cleaner command
routing, and several bugs have been fixed including a tracer restoration
issue in the agent ensure clause and a missing cursor in the REPL input
area.

### Add

* **repl: allow runtime state to be saved and restored** <br>
  `LLM::Agent#repl` now accepts a `path:` option that serializes
  runtime state to the filesystem. When the path already exists,
  runtime state is restored when the read-eval-print loop starts.
  Otherwise the path is written after the first turn, making it
  possible to resume a session across process restarts.

* **repl: scroll to the bottom on submit** <br>
  The curses-based REPL now scrolls the transcript to the bottom when
  the user submits their input, so the latest response is visible
  without needing to scroll down manually.

* **repl: add Ctrl+F to move the cursor forward** <br>
  The curses-based REPL input now supports Ctrl+F to move the cursor
  forward by one column, matching common terminal editing conventions
  found in shells like `/bin/sh`.

* **repl: add Ctrl+K to erase from cursor to end of line** <br>
  The curses-based REPL input now supports Ctrl+K to erase all text
  from the cursor position to the end of the input buffer, matching
  common terminal editing conventions found in shells like `/bin/sh`.

* **repl: add Ctrl+Y to paste previously killed text** <br>
  The curses-based REPL input now supports Ctrl+Y to insert the most
  recently killed text (via Ctrl+K) at the current cursor position,
  matching the yank/paste convention found in shells like `/bin/sh`.
  The killed text is stored in an internal copy buffer so it can be
  pasted multiple times or at different cursor positions.

* **repl: add command system foundation** <br>
  Add `LLM::Repl::Command` as a new base class for REPL commands,
  along with the first built-in command `LLM::Repl::Command::Exit`
  which exits the read-eval-print loop via `throw(:exit)`.
  Commands are identified by a name and can be looked up through
  `Command.find_by`. This is the foundation for the `/` command
  syntax used in the REPL input line.

* **repl: connect the command system to user input** <br>
  The curses-based REPL now routes user input through the command
  system. Any input string beginning with `"/"` is matched against
  the command registry via `Command.find_by`, and the corresponding
  command is executed instead of being forwarded to the model.
  This makes built-in commands like `/exit` functional from the
  input line. Command arguments are not yet supported.

* **repl: add `LLM::Repl::Command.registry`** <br>
  Add `LLM::Repl::Command.registry` for auto-registering command
  subclasses. The `inherited` hook captures each new subclass and
  stores it in the registry, making it possible to enumerate all
  available commands at runtime. Built-in commands like Exit are
  automatically registered when the command file is loaded.

* **repl: detect and handle paste mode in the input line** <br>
  The curses-based REPL input now detects paste operations by tracking
  the rate at which characters arrive. A paste rate of ≤50ms is
  assumed to be a burst of characters that could only be explained by
  a paste. No human types that fast. Multiline pastes are supported
  through internal refactoring of the input handling logic.

* **repl: optimize paste mode rendering** <br>
  Track the paste state with an internal `@paste` variable and switch
  to a faster input path during paste operations. While in paste mode,
  the input buffer is drained via `Curses.getch`, bypassing the more
  expensive char-by-char render path used for ordinary interactive
  input. This makes pasting large amounts of text noticeably faster.

* **Add `LLM::Tool::Ls`** <br>
  Add a built-in tool for listing files and directories, with optional
  glob pattern filtering to narrow results. <br>
  It must be required explicitly with `require "llm/tools/ls"`.

* **Add `LLM::Tool::Which`** <br>
  Add a built-in tool for locating an executable on the system PATH.
  This lets an agent check whether a command is available before
  attempting to run it, avoiding failed subprocess calls. <br>
  It must be required explicitly with `require "llm/tools/which"`.

* **repl: render tool calls in a function-call syntax** <br>
  The curses-based REPL status bar now renders tool calls with a
  compact function-call syntax: `tool(key: value)` instead of
  `tool: name`. Strings are quoted and truncated, arrays show their
  first two elements, and hashes collapse to `{…}`, making it easier
  to see what arguments the model is passing. The `tool done` status
  message has been removed since the tool call itself conveys
  completion information.

### Change

* **Refresh model metadata** <br>
  Update model listings, pricing, and capabilities across providers.
  Fix GPT-5.6 model family names in the OpenAI registry (`gpt` to
  `gpt-sol`, `gpt-nano` to `gpt-luna`, `gpt-mini` to `gpt-terra`).
  Add OpenAI models (`gpt-5.6-luna`, `gpt-5.6-sol`, `gpt-5.6-terra`)
  to the AWS Bedrock registry. Update DeepInfra pricing for
  `DeepSeek-V3` and `Sky-T1-32B-Preview`. Fix Google model knowledge
  cutoff dates.

* **repl: control the loop with catch & throw** <br>
  The curses-based REPL input loop now uses `catch(:exit)` and
  `throw(:exit)` instead of returning the `:exit` symbol and
  breaking out of the loop. This enables the `/command` syntax
  without requiring an `:exit` return value to be propagated
  through a potentially deeply nested call path.

* **repl: replace Ctrl+D with shell-like delete-at-cursor** <br>
  The curses-based REPL input now treats Ctrl+D as a delete action
  that removes the character at the current cursor position, matching
  the shell/Emacs convention where Ctrl+D deletes the character under
  the cursor instead of signalling end-of-file. The previous Ctrl+D
  behaviour (exiting the REPL) is superseded by the `/exit` command.

* **repl: switch to 'Thinking' mode after tool return** <br>
  The curses-based REPL status line now switches to "Thinking" mode
  after a tool returns, so the user can see the agent is processing
  the tool result rather than showing a stale tool-call status.

### Fix

* **agent: fix a subtle typo in the ensure clause** <br>
  Fix a subtle typo in `LLM::Agent` where the deprecated `trace` local
  variable was given preference over `tracer` (the preferred local name)
  in an `ensure` clause. The `trace` local was supported for backward
  compatibility but the ensure clause still referenced `trace` instead of
  `tracer`, which meant the previous tracer was never restored when the
  REPL session ended.

* **repl: restore the cursor in the input area** <br>
  Remove the `Curses.curs_set(0)` call from the REPL redraw method,
  which was inadvertently hiding the cursor and making it impossible
  to see the current position in the input area. The input field is
  now always drawn at its full height so the cursor position is
  correctly maintained after each redraw.

## v12.3.1

Changes since `v12.3.0`.

This release fixes a flickering issue in the curses-based REPL redraw.
The full-screen clear that caused visible flickering has been replaced
with a targeted cursor-hide approach, and stale rows from a larger
transcript are now explicitly cleared to prevent ghost text from
lingering when the transcript shrinks.

### Fix

* **repl: fix redraw flicker** <br>
  Replace `Curses.clear` with `Curses.curs_set(0)` in the REPL redraw
  method to avoid a full screen clear that caused visible flickering
  during redraws. The drawing order is also adjusted so the status line
  is drawn before the divider, and stale rows left over from a larger
  transcript are now explicitly cleared to prevent ghost text from
  lingering when the transcript shrinks.

## v12.3.0

Changes since `v12.2.0`.

This release brings major improvements to the curses-based REPL
(`LLM::Agent#repl`). The status line now shows a context-usage bar and
running cost counter, the input field expands to three rows with
full cursor navigation, model responses are rendered as styled markdown,
and the UI stays responsive while the agent is working by running
requests in a separate thread. A new `LLM::Stream::IO` and
`LLM::Stream::Disabled` provide a uniform stream representation across
all stream types.

Mistral OCR support is added for extracting text from images and
documents via the `/v1/ocr` endpoint. The `skills:` and `tools:` options
on `LLM::Agent#repl` let you attach additional tools or skill directories
for the duration of a session. `LLM::Object#merge!` rounds out the
in-place merge API, and a new `LLM.logger` convenience method creates
tracer logger instances with less verbosity.

### Add

* **Add `LLM.logger` convenience method** <br>
  Add `LLM.logger(llm, ...)` as a shorter, less verbose way to create an
  `LLM::Tracer::Logger` instance. Takes a provider and optional keyword
  arguments forwarded to the logger constructor.

* **Add `skills:` option to `LLM::Agent#repl`** <br>
  `LLM::Agent#repl` now accepts a `skills:` keyword argument that attaches
  one or more skill directories (containing `SKILL.md`) for the duration of
  the repl session. Skills are loaded and converted to tools, combining with
  any tools already configured on the agent, and are discarded when the
  session ends.

* **Add `LLM::Provider#ocr` base method** <br>
  Add a base `ocr(...)` method to `LLM::Provider` that raises `NotImplementedError`
  by default, establishing a common interface for providers that support OCR
  (Optical Character Recognition) on images and documents.

* **Add Mistral OCR endpoint support** <br>
  The Mistral provider now supports OCR via its `/v1/ocr` endpoint. Call
  `mistral.ocr(image_url: ...)` for images or `mistral.ocr(document_url: ...)`
  for documents (e.g., PDFs). Returns an `LLM::Response` with extracted pages,
  markdown content, and structured block data.

* **Add `LLM::Object#merge!`** <br>
  Add `LLM::Object#merge!` for in-place merging of hash data into an
  `LLM::Object` instance, complementing the existing `#merge` method.

* **Add `LLM::Stream::IO` and `LLM::Stream::Disabled`** <br>
  `LLM::Stream::IO` wraps IO-like objects as stream targets, forwarding
  streamed content via `#<<`. `LLM::Stream::Disabled` represents an explicitly
  disabled stream with no-op callbacks.

  This is part of an internal refactoring that lets all stream values: IO
  objects, `true`, `false`, `nil`, and `LLM::Stream` instances themselves
  be represented by the same `LLM::Stream` interface via the new
  `LLM::Stream.try` factory method.

  Before this change the codebase had to perform ad-hoc type checks
  (e.g. `if LLM::Stream === stream`) scattered throughout. After this
  change all stream handling goes through a single uniform path, and
  providers check `#enabled?` to decide whether to request streaming
  from the API.

### Change

* **repl: rename `trace:` to `tracer:`** <br>
  The `trace:` keyword argument in `LLM::Agent#repl` has been renamed to
  `tracer:` for consistency with the rest of the codebase. The old `trace:`
  name still works with a deprecation warning.

* **repl: add context-usage bar and cost counter to the status line** <br>
  The curses-based REPL status line now shows a small progress bar that
  indicates how much of the model's context window remains as a percentage,
  alongside a running cost estimate rendered on the right side of the status
  line. The input line has been updated to show the provider name as a prefix.
  Estimates are best-effort and depend on registry pricing data (see `data/`).

* **repl: keep the UI responsive while a request is in progress** <br>
  The curses-based REPL now spawns the agent request in a separate thread
  and communicates streamed output through a queue, so the curses UI stays
  responsive during model processing. Users can continue to scroll through
  the transcript while the agent is working.

* **repl: style transcript rows as structured data with bold labels** <br>
  The curses-based REPL transcript now stores rows as structured data with
  style metadata instead of plain strings, enabling bold rendering of the
  `user:` and `agent:` labels for improved readability during interactive
  sessions.

* **repl: render a small subset of markdown** <br>
  The curses-based REPL now renders model responses as styled markdown.
  Headers and strong text render in bold, emphasis renders in underline,
  and code spans and blocks are highlighted with inverted colors. Streaming
  content is buffered and re-rendered on each tick so the transcript reads
  cleanly as the agent responds. Requires the optional `kramdown` gem.

* **repl: add cursor LEFT/RIGHT movement to the input line** <br>
  The curses-based REPL input now supports cursor movement with the left
  and right arrow keys, enabling in-place text editing before submitting
  a prompt. The cursor position is tracked visually and moves backwards
  on left-arrow and forwards on right-arrow.

* **repl: add Ctrl+A and Ctrl+E keybindings to the input line** <br>
  The curses-based REPL input now supports Ctrl+A to jump the cursor to
  the start of the input line and Ctrl+E to jump it to the end, matching
  common terminal editing conventions.

* **repl: add `tools:` option to `LLM::Agent#repl`** <br>
  `LLM::Agent#repl` now accepts a `tools:` keyword argument that attaches
  additional tool classes or instances for the duration of the repl session.
  These tools are combined with any tools already configured on the agent,
  and are discarded when the session ends.

* **repl: add repl support to ActiveRecord and Sequel agent models** <br>
  `acts_as_agent` (ActiveRecord) and `plugin :agent` (Sequel) models now
  expose a `repl` method that delegates to the underlying agent's
  read-eval-print loop. This allows interactive debugging and inspection
  of persisted agent state at runtime. Note that changes made during a
  repl session do not persist back to the database.

* **repl: add extra padding between markdown nodes** <br>
  The curses-based REPL markdown renderer now adds extra vertical spacing
  between certain markdown elements: paragraphs, headers, and codeblocks
  for improved readability of model responses.

* **repl: add a visual divider between transcript and the rows below it** <br>
  The curses-based REPL now draws a horizontal divider line (using a unicode
  `─` character) to separate the transcript area from the status and input
  rows below it. A single empty buffer row is also added between the
  transcript and the divider, preventing transcript text from running too
  close to the status and input rows.

* **repl: expand input field to 3 rows** <br>
  The curses-based REPL input field now spans three rows instead of one,
  wrapping text that exceeds the terminal width onto subsequent lines. A
  scrollable viewport follows the cursor so the active line stays visible,
  and common navigation commands (Ctrl+A, Ctrl+E, cursor keys) work across
  all three rows of the expanded input area.

* **Refresh OpenAI model metadata** <br>
  Add new OpenAI models to the registry, including `gpt-5.6`,
  `gpt-5.6-luna`, `gpt-5.6-terra`, `gpt-5.6-sol`, and
  `gpt-realtime-2.1`, with associated pricing, capabilities, and
  limits.

### Fix

* **Fix Ollama non-streaming response handling** <br>
  Fix the Ollama provider to properly handle the non-streaming path. When
  the provider returns a raw NDJSON response body (instead of streaming),
  the response is now parsed and merged into a single `LLM::Object` before
  being returned to the caller. Previously the non-streaming path was
  effectively broken and would fail to produce a valid completion response.

* **repl: handle a negative context window allowance in the usage bar** <br>
  Fix a crash in the curses-based REPL context-usage bar when the context
  window allowance is exceeded (used > total). The negative width value that
  resulted from this edge case could cause curses errors; it now gracefully
  defaults to `0%` and zero bar width.

* **Fix YARD documentation across provider and tool files** <br>
  Fix unnamed, misnamed, and missing `@param` tags in `LLM::Repl::Status`,
  `LLM::Tool::Git`, `LLM::Tool::Pwd`, `LLM::Tool::Rg`, and
  `LLM::Tool::SwapText`.

## v12.2.0

Changes since `v12.1.0`.

This release adds Mistral as a new provider with chat completions, streaming, tool calls,
structured outputs, file/image attachments, and embeddings support. It introduces
the `trace:` option to `LLM::Agent#repl` for keeping the tracer active during
interactive sessions.

Several fixes land for the Google provider (generationConfig parameter leakage),
`LLM::Context#tracer=` (always assigning nil), `LLM::Provider#with_tracer(nil)`
(nil fallback), and `LLM::Context#repair!` (dropping Struct returns).

The default HTTP timeout has been increased from 60s to 180s to better accommodate
reasoning models and large structured outputs, and the Anthropic default model has
been updated to `claude-opus-4-8`. Model metadata has been refreshed across
Anthropic, AWS Bedrock, DeepInfra, Google, and xAI, with Mistral model data added
to the registry.

### Add

* **Add `trace:` option to `LLM::Agent#repl`** <br>
  `LLM::Agent#repl` now accepts a `trace:` keyword argument. By default
  the tracer is disabled for the duration of the repl session to prevent
  curses UI interference from output written to `$stdout` or `$stderr`.
  Set `trace: true` to keep the tracer active during the session, which
  is useful when the tracer writes to a file rather than the terminal.

* **Add a new provider: LLM::Mistral** <br>
  [Mistral](https://mistral.ai) is now supported through its
  OpenAI-compatible API. The provider supports chat completions,
  streaming, tool calls, structured output (schema), file/image
  attachments, and embeddings. Use `LLM.mistral(...)` to create a
  provider instance.

* **Add `LLM.mistral(...)` convenience method** <br>
  A new top-level accessor (`LLM.mistral`) returns an `LLM::Mistral`
  provider instance, matching the pattern used by other providers.

### Fix

* **Fix Google `generationConfig` parameter leakage** <br>
  Fix a bug in the Google provider where non-generation parameters
  (`role`, `model`, `messages`, `stream`) were leaking into the
  `generationConfig` object alongside legitimate generation config
  parameters such as `temperature`. Non-config parameters are now
  filtered out before constructing `generationConfig`.

* **Fix `LLM::Context#tracer=` always assigning `nil`** <br>
  The `LLM::Context#tracer=` setter had a bug where it always assigned
  `nil` regardless of the tracer value passed. It now correctly assigns
  the given tracer or falls back to `LLM::Tracer::Null`.

* **Fix `LLM::Provider#with_tracer(nil)` fallback** <br>
  `LLM::Provider#with_tracer(nil)` now falls back to
  `LLM::Tracer::Null` instead of setting a `nil` tracer directly.

* **Fix `LLM::Context#repair!` dropping `Struct` returns** <br>
  `LLM::Context#repair!` used `[*prompt]` to wrap the prompt before
  grepping for return objects. Since `LLM::Function::Return` is a
  `Struct`, the splat operator expanded it into its member values
  instead of wrapping it, causing the grep to silently drop returns.
  The fix wraps both sources in an array before flattening.

### Change

* **Increase default provider timeout from 60s to 180s** <br>
  The default HTTP timeout for all providers has been increased from
  60 to 180 seconds to better accommodate long-running requests such
  as reasoning models and large structured outputs.

* **Change Anthropic default model to `claude-opus-4-8`** <br>
  The default Anthropic chat model has been updated from
  `claude-sonnet-4-20250514` to `claude-opus-4-8`, reflecting the
  latest model release from Anthropic.

* **Refresh model metadata** <br>
  Update model listings, pricing, and capabilities for Anthropic,
  AWS Bedrock, DeepInfra, Google, and xAI. Add Mistral model data
  to the registry.

## v12.1.0

Changes since `v12.0.0`.

This release adds `LLM::Agent#repl` with a curses-based
interactive read-eval-print loop. It requires the optional
dependency `curses` and it is probably the most notable
feature in this release.

Multiple _opt-in_ tools have been added to the `llm/tools/*.rb`
directory. They serve as examples and as general-purpose tools
that happen to power the repository's agents.

The BSL license has been extended to grant additional free waivers
for non-profits, charities and for companies with 50 or less
employees.

Other changes include small-ish bug fixes. <br>
As always, see the changelog details for a thorough overview.

### Add

* **Add `LLM::Agent#repl`** <br>
  Add a curses-based read-eval-print loop for `LLM::Agent` that lets
  developers interact with an agent after it has been set up or has
  performed a task. It is similar to `binding.pry`: once you exit,
  you can continue with the rest of your program. It requires the
  `curses` gem.

* **Add `#tracer=` setter on Provider, Context and Agent** <br>
  `LLM::Provider`, `LLM::Context` and `LLM::Agent` can now configure
  the tracer after initialization via the `#tracer=` setter. It accepts
  a subclass of `LLM::Tracer` or `nil` to disable the tracer.

* **Add `LLM::Tool::Shell`** <br>
  Add a built-in shell tool that can run a command with arguments. <br>
  It must be required explicitly with `require "llm/tools/shell"` and
  requires the `test-cmd.rb` gem.

* **Add `LLM::Tool::ReadFile`** <br>
  Add a built-in tool for reading the contents of a file, with optional
  `start` and `stop` line offsets. <br>
  It must be required explicitly with `require "llm/tools/read_file"`.

* **Add `LLM::Tool::Chdir`** <br>
  Add a built-in tool for changing the current working directory. <br>
  It must be required explicitly with `require "llm/tools/chdir"`.

* **Add `LLM::Tool::Git`** <br>
  Add a built-in tool that can perform git actions (`log`, `diff`,
  `show`, `commit`, `checkout`, `branch`). <br>
  It must be required explicitly with `require "llm/tools/git"` and requires the `test-cmd.rb` gem.

* **Add `LLM::Tool::Rg`** <br>
  Add a built-in tool that wraps the `rg` (ripgrep) command for
  recursively searching the current directory for patterns. <br>
  It must be required explicitly with `require "llm/tools/rg"` and requires the `test-cmd.rb` gem.

* **Add `LLM::Tool::SwapText`** <br>
  Add a built-in tool that can replace an exact snippet of text in a
  file with a new piece of text. <br>
  It must be required explicitly with `require "llm/tools/swap_text"`.

* **Add `LLM::Tool::Pwd`** <br>
  Add a built-in tool that returns the current working directory. <br>
  It must be required explicitly with `require "llm/tools/pwd"`.

* **Add `LLM::Tool::WriteFile`** <br>
  Add a built-in tool that can write a given string to a given file
  path. <br>
  It must be required explicitly with `require "llm/tools/write_file"`.

* **Add `LLM::Tool::Mkdir`** <br>
  Add a built-in tool that can create a tree of new directories. <br>
  It must be required explicitly with `require "llm/tools/mkdir"` and
  requires the `test-cmd.rb` gem.

### Change

* **Extend BSL additional use grant** <br>
  The Business Source License additional use grant has been extended to
  include non-profits, charities, and companies with 50 or fewer
  employees, in addition to the existing personal, education, and
  evaluation uses.

* **Change LlamaCpp default port (8080 => 8013)** <br>
  The default port for the LlamaCpp provider has changed from `8080` to
  `8013` since llamacpp itself defaults to that port.

* **Change LlamaCpp default model to `nil`** <br>
  The default model for LlamaCpp is now `nil`, letting whatever model
  is served by the llamacpp server act as the default. Previously it
  defaulted to `qwen3`.

### Fix

* **Fix `LLM::Agent.tools` Symbol resolution** <br>
  When an agent defined tools via `tools :method_name`, the resolved
  symbol was incorrectly forwarded as `[:method_name]` (an array) to
  `LLM::Context`. This fix copies the same pattern used by other
  attribute resolvers (e.g., `skills`) so a single Symbol is resolved
  through the agent instance correctly.

* **Encode strings as UTF-8 in the JSON adapter** <br>
  The `json` gem will reject BINARY-encoded strings from version 3 and
  beyond. The `LLM::JSONAdapter.dump` method now walks serialized data
  and encodes every string into UTF-8, using `String#scrub` to replace
  bytes that are not valid UTF-8.

## v12.0.0

Changes since `v11.3.1`.

This release relicenses the project under the Business Source License,
defaults OpenAI to the Responses API and gpt-image models, adds the
DeepInfra provider with audio and image support, introduces
DeepSeek vector-graphics generation and schema support, extends xAI
image editing, adds `LLM::Schema.defaults` and schema string rendering,
and makes ActiveRecord and Sequel agent wrappers yield `LLM::Agent`
instead of polluting the model namespace.

### Breaking

* **License change** <br>
  The llm.rb runtime has been developed primarily by one
  person for 3 years. That was done on my own time, and
  I haven't made a dime from that work.

  So when I saw a multi-million dollar company benefit from
  the work and for it to become the backbone of their AI
  infrastructure and then see them not contribute back or
  offer any kind of support, I decided this is not sustainable,
  or fair.

  I assumed good faith and for people to act in the spirit of
  open source but sadly, that's just not the case. I
  have to choose a license that respects my time and effort.

  For those reasons, llm.rb is being relicensed under the
  [Business Source license](https://mariadb.com/bsl11/).
  So what does that mean?

  In a nutshell:

  * Free for personal use.
  * Free for education.
  * Free for evaluation, development, and testing.
  * Commercial production use requires a commercial license.
  * Exemptions on a case-by-case basis

  After 4 years, the license expires and it will become
  available under the 0BSDL as it was before v12.0.0.
  These 4 years apply to a specific version, and not the
  project overall.

  Going forward, v12.0.0 will be relicensed to respect
  my time, energy, and effort. llm.rb took an incredible
  amount of time and effort, and continues to do so, so
  I want to protect myself from companies who benefit
  from my work but don't respect the time or effort that
  was put into it.

* **OpenAI: default to the Responses API** <br>
  The responses API has both models and features that are unavailable
  on the chat completions API, and the responses API appears to be
  the API of the future for OpenAI.

  Worth noting: the llm.rb implementation does **not** store state
  server-side by default. This can be changed with the `store: true`
  option. The legacy chat completions API can be accessed with the
  `mode: :completions` option.

  llm.rb has had support for the responses API for quite
  a while but it was not the default, and a number of bugs
  were found and fixed during the process of making it the
  default.

* **OpenAI: use gpt-image for image generation** <br>
  The `dalle` models are in the process of being deprecated, and support
  has been dropped from llm.rb. The `gpt-image` models are the next-generation
  image-generation models from OpenAI.

* **xAI: provide images as base64-encoded data** <br>
  Both xAI, and OpenAI had the option to generate images via a URL
  you can fetch, or as a base64-encoded string embedded directly
  in the response.

  OpenAI is moving away from the URL transport since deprecating dalle,
  and with that in mind, llm.rb has dropped support for the URL transport
  across all providers that supported it.

  Google, xAI, and OpenAI now consistently provide generated and modified
  images as a base64-encoded string.

* **ActiveRecord: yield `LLM::Agent` to `acts_as_agent`** <br>
  With this change we yield an instance of `LLM::Agent` to the `acts_as_agent`
  method, and drop the methods (such as `model`, `instructions`, etc) that
  were previously defined directly on the model. This keeps the number of
  methods that llm.rb adds to an ActiveRecord model at a minimum and retains
  the same capabilities as before.

* **Sequel: yield `LLM::Agent` to `plugin(:agent)`** <br>
  Ditto as above but for Sequel.

* **Remove the langsmith tracer** <br>
  This code was contributed by a third party but contains
  many anti-patterns that are against llm.rb conventions
  and best practices. It was merged without oversight or
  review, and basically against the ethos of open source.

  I also don't have a langsmith account to maintain the
  code. The alternative is the `LLM::Tracer::Telemetry` class
  that was originally written by me, and serves as a
  general-purpose OTP tracer.

### Add

* **Add a new provider: LLM::DeepInfra** <br>
  [DeepInfra](https://deepinfra.com) provide OpenAI-compatible
  endpoints for a large catalog of hosted open-source and
  open-weight models. <br> Capabilities like tool calling, structured outputs, and
  reasoning can depend on the model.

* **Add new image provider: LLM::DeepInfra::Images** <br>
  [DeepInfra](https://deepinfra.com) provide access to
  diverse set of text-to-image models. <br> Learn more about the
  available models on their [text-to-image models](https://deepinfra.com/models/text-to-image)
  page.

* **DeepSeek: add `LLM::DeepSeek::Images#create` and `#edit`** <br>
  This new API can generate and edit vector graphics (SVGs). <br>
  It is an experimental approach and API.

  DeepSeek does not provide an image generation model however
  its text-to-text models can generate SVG documents, and
  that's the approach this feature takes. It is limited
  to vector graphics rather than raster images.

* **DeepSeek: attach `LLM::Response#agent` to image responses** <br>
  The DeepSeek image API is built on top of
  [`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html).
  Image responses now expose that agent via `res.agent`, which makes
  it possible to carry the same session across multiple generations
  or edits.

* **xAI: add `LLM::XAI::Images#edit`** <br>
  With this change it is possible to both generate images
  from a prompt, and edit an existing image with a prompt.
  xAI now has the same edit and create capabilities that
  OpenAI has.

* **Add `LLM::Schema.defaults`** <br>
  This method lets you map multiple property names to
  different default values. It is similar to `LLM::Schema.required`
  in the sense that it is called after the properties of
  a schema have been defined.

* **Add `LLM::Schema#to_s` and `LLM::Schema.to_s`** <br>
  Schemas can now be rendered as a prompt-friendly string.
  This is useful when the shape of a schema needs to be
  described in natural-language instructions rather than
  passed through a native structured output interface.

* **DeepSeek: add `LLM::Schema` support** <br>
  DeepSeek can now use `schema:` for structured output.
  llm.rb handles this by setting `response_format: {type: "json_object"}`
  and describing the schema in a system message.

* **OpenAI: add local file support to the Responses API** <br>
  Our responses API implementation lacked local file support. <br>
  This change fixes that by supporting both image, document,
  and other media types that OpenAI may support.

* **Add `LLM::Response#id` across all providers** <br>
  This method was previously implemented via `method_missing`,
  and the field name could change depending on the provider.
  The new method is a catch-all that provides a single method
  that works across all providers.

* **Add `LLM::DeepInfra::Audio`** <br>
  DeepInfra implements most of the llm.rb audio interface
  with both the `create_speech` and `create_transcription`
  methods. The `create_translation` method is not implemented,
  and the available text-to-speech and speech-to-text models
  are more varied than other providers.

* **OpenAI: normalize text-to-speech responses** <br>
  The `res.audio` method now returns an
  [`LLM::URIData`](https://r.uby.dev/api-docs/llm.rb/LLM/URIData.html)
  object for OpenAI text-to-speech responses. The object provides
  `encoded`, `decoded`, `content_type`, and `encoding_type`.

* **DeepInfra: normalize text-to-speech responses** <br>
  The `res.audio` method now returns an
  [`LLM::URIData`](https://r.uby.dev/api-docs/llm.rb/LLM/URIData.html)
  object for DeepInfra text-to-speech responses. The object provides
  `encoded`, `decoded`, `content_type`, and `encoding_type`.

### Fix

* **Fix Google `temperature` parameter fall-through** <br>
  Ensure provider-level `temperature` and other `generationConfig`
  parameters are forwarded to the API correctly instead of being
  silently dropped.

* **Fix Google `generationConfig` collisions** <br>
  Prevent duplicate or conflicting `generationConfig` keys in the
  Google request adapter.

### Change

* **Change OpenAI defaults** <br>
  The default chat model is now `gpt-5.4-mini`. <br>
  The default image model is now `gpt-image`.

* **Change google defaults** <br>
  The default chat model is now `gemini-3.1-flash-lite` <br>
  The default embeddings model is now `gemini-embedding-2`

* **Change xAI defaults** <br>
  The default chat model is now `grok-4.3`. <br>
  The default image model is now `grok-imagine-image-quality`.

* **Return an `LLM::Object` from `LLM::Response#content!`** <br>
  The Hash-like, indifferent access data structure known as
  `LLM::Object` provides a convenient interface around a Hash
  object. It allows method access via `obj.key`, and decays
  into a Hash in many cases.

  The `LLM::Response#content!` method now wraps its content
  in an `LLM::Object` but only after it has parsed its
  content (a JSON string) into a Ruby data structure.

* **Refresh model metadata** <br>
  Update `data/*.json` files with current provider model listings,
  pricing, and capabilities.

## v11.3.1

Changes since `v11.3.0`.

This release rebrands the project under the r.uby.dev umbrella, removes
the Jekyll-based docs site in favor of a pure-markdown deepdive, and
cleans up YARD documentation across the codebase.

### Change

* **Rebrand to r.uby.dev** <br>
  Update README.md with the new logo, streamlined copy, and r.uby.dev
  URLs. Rewrite `resources/deepdive.md` as a concise walkthrough and
  bundle it with the gem. Remove the `docs/` directory (Jekyll site).
  Update all references from `llmrb.github.io` to `r.uby.dev`.

* **Update gemspec** <br>
  Update homepage, metadata URLs, email, and author list. Switch the
  YARD markdown processor from kramdown to redcarpet.

### Fix

* **Fix YARD documentation** <br>
  Fix unnamed, misnamed, and missing `@param` tags across provider
  adapters, transport classes, stream, tool, schema, registry, agent,
  and ActiveRecord integration files. Fix backtick-wrapped constant
  references and other YARD formatting issues.

## v11.3.0

Changes since `v11.2.0`.

This release promotes `LLM::Agent` as the default high-level runtime,
raises `LLM::NotFoundError` for provider 404 responses, and adds
Symbol resolution to `LLM::Agent.confirm` and `LLM::Agent.skills` for
dynamic tool confirmation and skill lists.

### Add

* **Raise `LLM::NotFoundError` for provider 404 responses** <br>
  Raise `LLM::NotFoundError` when a provider returns HTTP 404. One
  example is calling the embeddings API on DeepSeek
  (`LLM.deepseek(...).embed(["foobar"])`), which returns 404 because
  DeepSeek does not implement that endpoint.

* **Add Symbol resolution to `LLM::Agent.confirm`** <br>
  When `confirm` receives a single Symbol argument, it stores it
  as-is instead of converting it to a string array. At initialization
  time, `resolve_option` resolves the Symbol by calling the method
  with that name on the agent instance, and the result is converted
  to strings. This allows dynamic tool confirmation lists:

      class MyAgent < LLM::Agent
        confirm :tools_that_need_confirmation

        def tools_that_need_confirmation
          some_condition ? %w[delete destroy] : %w[delete]
        end
      end

  Ported from llmrb/mruby-llm@89a232e3 and @2dd04e2d.

  Extend the same pattern to `LLM::Agent.skills` so the skills DSL
  accepts a Symbol that resolves through the agent instance at
  initialization time.

### Change

* **Clarify `LLM::Agent` as the default high-level runtime** <br>
  Document that `LLM::Context` remains at the heart of llm.rb, but
  `LLM::Agent` is the better default unless an application needs advanced
  manual tool loops. `LLM::Agent` manages the tool loop for callers and
  enables guards against runaway or repeated tool-call loops.

## v11.2.0

Changes since `v11.1.0`.

This release adds `LLM::Function#skill?` and `LLM::Tool#skill?` so
callers can inspect whether a function or tool is backed by a skill.

It introduces `LLM::Transport::Request` as a transport-agnostic request
object so providers no longer depend directly on `Net::HTTP` request
classes, and adds an optional Curb (libcurl) backend alongside symbolic
transport shortcuts such as `transport: :curb`.

MCP and A2A clients now accept `persistent: true` matching provider configuration.
Several fixes land for tool return callback emission, function comparison by
tool call ID, function array filtering, skill tool inheritance, and JSON generator
state compatibility on Ruby 4.

### Add

* **Add `LLM::Function#skill?`** <br>
  Add `skill?` to `LLM::Function` so callers can check whether a
  function is backed by a skill tool.

* **Add `LLM::Tool.skill?` and `LLM::Tool#skill?`** <br>
  Add class-level `skill?` and instance-level `skill?` to
  `LLM::Tool`, matching the existing `mcp?` and `a2a?` pattern.

* **Add `LLM::Transport::Request`** <br>
  Add `LLM::Transport::Request` as a transport-agnostic request object
  and update providers to build requests without depending directly on
  Net::HTTP request classes. The built-in Net::HTTP transports still
  accept existing Net::HTTP request objects through a compatibility
  bridge, while alternative transports can handle the generic request
  shape directly.

* **Add optional Curb transport support** <br>
  Add `LLM::Transport::Curb`, an optional libcurl-backed transport
  that can be selected with `transport: :curb`. Providers already
  emit `LLM::Transport::Request` objects, so the Curb backend can
  execute requests without routing through Net::HTTP.

* **Add symbolic transport shortcuts** <br>
  Allow providers, MCP HTTP clients, and A2A HTTP clients to accept
  transport shortcuts such as `transport: :curb` and
  `transport: :net_http_persistent`.

* **Add persistent HTTP selection to MCP and A2A clients** <br>
  Allow MCP and A2A HTTP clients to accept `persistent: true`, matching
  provider configuration and selecting the persistent Net::HTTP
  transport by default.

### Fix

* **Support JSON generation state on Ruby 4** <br>
  Handle JSON generator state objects in the standard JSON adapter so
  schema objects serialize correctly when Ruby 4 calls custom `to_json`
  methods during provider request generation.

* **Emit tool return callbacks for direct context waits** <br>
  Emit `LLM::Stream#on_tool_return` when `LLM::Context#wait` executes
  pending tool work directly instead of draining `LLM::Stream::Queue`.

* **Emit confirmed tool return callbacks once** <br>
  Emit `LLM::Stream#on_tool_return` for confirmed and cancelled tool
  calls, and exclude confirmed functions from later waits so mixed
  confirmed and unconfirmed tool batches do not execute confirmed tools
  twice.

* **Compare functions by tool call ID** <br>
  Add `LLM::Function#==`, `#eql?`, and `#hash` so pending function
  collections can compare tool calls by provider-assigned ID instead of
  object identity.

* **Preserve function array behavior after filtering** <br>
  Preserve `LLM::Function::Array` behavior when subtracting function
  arrays so filtered tool batches can still spawn through the normal
  function array API.

* **Prevent skills from inheriting skill-backed tools** <br>
  Exclude skill-backed tools when a skill sub-agent uses `tools:
  inherit`, preventing skills loaded through a parent context from
  being recursively exposed to nested skill agents.

## v11.1.0

Changes since `v11.0.0`.

This release adds the `inherit` directive for skill sub-agents so they can
inherit access to the local, MCP, and A2A tools available to their parent
agent. It introduces class-level `required %i[...]` declarations to
`LLM::Schema` and wraps `LLM::Function#arguments` in `LLM::Object` for
method-style argument access. The OpenTelemetry tracer now samples all spans
regardless of environment, and the tool-call loop repair step prevents stale
history from being sent on follow-up requests.

### Add

* **Add support for the `inherit` directive in skills** <br>
  Add support for the `inherit` directive so a skill sub-agent can
  inherit access to the local, MCP, and A2A tools available to its
  parent agent.

* **Add class-level `required %i[...]` support to `LLM::Schema`** <br>
  Add class-level `required %i[...]` declarations to `LLM::Schema`, so
  schema classes can mark existing properties as required the same way
  `LLM::Tool` params already can.

* **Wrap function arguments in `LLM::Object`** <br>
  Wrap `LLM::Function#arguments` in `LLM::Object`, so function
  implementations can read arguments with method-style access while
  still invoking runners with keyword arguments.

### Fix

* **Ensure all traces are sampled regardless of environment** <br>
  Explicitly pass `Samplers::ALWAYS_ON` when creating the OpenTelemetry
  `TracerProvider` so the in-memory exporter always captures every span,
  regardless of the `OTEL_TRACES_SAMPLER` environment variable.

* **Always close the tool call loop before sending follow-up requests** <br>
  Add a repair step in `Context#talk` that closes assistant tool-call
  messages without matching tool responses before the next provider
  request is sent. This prevents stale tool-call history from being sent
  on follow-up requests, which some providers reject as invalid.

## v11.0.0

Changes since `v10.0.0`.

This release removes several deprecated or unused APIs, including the `#chat`
alias from contexts and agents, the `LLM::Function#register` alias, and the
unused positional `llm` argument from MCP constructors. Generated MCP and A2A
tools are no longer added to the global tool registry by default.

On the additions side, it introduces the A2A (Agent2Agent) protocol client,
a new `#ask` convenience interface on contexts and agents, one-shot stdio MCP
requests outside `#session`, `LLM::Function#def` as a short alias for
`LLM::Function#define`, `LLM::File#exist?`, and `LLM::Tool.a2a?`.

### Breaking

* **Remove the unused `llm` argument from MCP clients** <br>
  Remove the unused positional `llm` argument from `LLM::MCP.new`,
  `LLM::MCP.stdio`, `LLM::MCP.http`, and `LLM.mcp`.

* **Stop globally registering generated MCP and A2A tools** <br>
  Generated tools returned by `LLM::Tool.mcp(...)` and
  `LLM::Tool.a2a(...)` are no longer added to the global
  `LLM::Tool.registry` or `LLM::Function.registry`. They still work
  when passed directly to a context or agent, but registry-based lookup
  now only sees normal loaded `LLM::Tool` subclasses.

* **Remove `LLM::Function#register`** <br>
  Remove the `LLM::Function#register` alias and prefer
  `LLM::Function#define` or `LLM::Function#def` when binding a
  function to its implementation. The `register` alias was too easy to
  confuse with the class-level `LLM::Tool.register` and
  `LLM::Function.register` registry APIs.

* **Remove the `#chat` alias from contexts and agents** <br>
  Remove the `LLM::Context#chat` and `LLM::Agent#chat` aliases. Prefer
  `#talk` for all context and agent turns.

### Add

* **Add `LLM::Function#def`** <br>
  Add `LLM::Function#def` as a short alias for
  `LLM::Function#define` when binding a function instance to its
  implementation.

* **Add `LLM::MCP#session`** <br>
  Add `LLM::MCP#session` as an alias for `LLM::MCP#run`, and prefer it
  in examples for scoped stdio MCP sessions that should stay alive
  across discovery and tool calls.

* **Add `#ask` to contexts and agents** <br>
  Add `LLM::Context#ask` and `LLM::Agent#ask` as a RubyLLM-compatible
  convenience interface over `#talk`. `#ask` accepts a prompt, optional
  `with:` attachments, an optional `stream:` target, and an optional
  block for streamed chunks, and returns an `LLM::Response`.

* **Add `LLM::File#exist?`** <br>
  Add `LLM::File#exist?` as a small convenience wrapper for checking
  whether a local file exists on disk.

* **Allow one-shot stdio MCP requests outside `#session`** <br>
  Allow `mcp.tools`, `mcp.prompts`, `mcp.find_prompt(...)`, and
  `mcp.call_tool(...)` to work outside `mcp.session` by starting and
  stopping a stdio transport on demand when needed. This makes stdio
  MCP usable without an explicit session block, while keeping
  `mcp.session` as the preferred pattern for efficient, stateful
  stdio workflows.

* **Add A2A client support** <br>
  Add `LLM::A2A`, a client for the Agent2Agent (A2A) protocol with
  REST and JSON-RPC bindings. Remote agent skills can be exposed as
  `LLM::Tool` classes and used through `LLM::Context` or `LLM::Agent`,
  and the client also supports direct messaging, streaming, task
  operations, push notification configuration, extended agent cards,
  persistent HTTP transport selection, and optional REST `base_path`
  prefixing.

  Refactor shared MCP/A2A HTTP transport setup into
  `LLM::Transport::Utils`, and extend
  `LLM::Transport::StreamDecoder` to accept a callback block directly.

* **Add `LLM::Tool.a2a?`** <br>
  Add `LLM::Tool.a2a?` and mark generated A2A-backed tool classes so
  callers can distinguish them from local or MCP tools.

### Fix

* **Fix context and agent JSON serialization through `LLM.json`** <br>
  Fix `LLM::Context#to_json` and `LLM::Agent#to_json` to serialize
  through `LLM.json.dump(...)` instead of plain `to_json`.

* **Fix block-form ORM agent DSL forwarding** <br>
  Fix block-form `model { ... }`, `tools { ... }`, and
  `schema { ... }` declarations in the ActiveRecord and Sequel agent
  wrappers so persisted agent models configure the internal agent class
  the same way `LLM::Agent` does.

* **Fix missing `skills` in ORM agent wrappers** <br>
  Fix the ActiveRecord and Sequel agent wrappers to expose `skills`, so
  persisted agent models can declare skills the same way as
  `LLM::Agent`.

* **Fix `acts_as_agent#ctx` return type** <br>
  Fix the ActiveRecord `acts_as_agent` wrapper so its `ctx` helper
  returns the wrapped `LLM::Agent` instead of returning the underlying
  `LLM::Context` directly.

## v10.0.0

Changes since `v9.0.0`.

This release removes the `LLM::Context#respond` method, and
also removes the deprecated `LLM::Bot` alias. **All** class-level
agent tunables can now be resolved lazily via a Symbol (method name),
or a Proc. The `LLM::Agent` class can now confirm a tool call
before it happens, and the `LLM::Schema` class has been extended
to support `Array[String,Integer]` as a shorthand for
`Array[AnyOf[String, Integer]]`. The `LLM::Stream` class has
had its public method surface reduced to help avoid accidental
collisions.

### Breaking

* **Unify context turns under `#talk`** <br>
  Remove `LLM::Context#respond` and route responses-mode turns through
  `LLM::Context#talk` with `mode: :responses` instead.

* **Remove the `LLM::Bot` alias** <br>
  Remove the backward-compatible `LLM::Bot` alias for `LLM::Context`.
  Use `LLM::Context` directly instead.

### Add

* **Add shared option resolution through `LLM::Utils`** <br>
  Add `LLM::Utils.resolve_option` for resolving configured values as
  literals, procs, symbol-named methods, or duplicated hashes, and use
  it in agent and ORM option resolution paths.

* **Resolve all class-level agent tunables via Proc** <br>
  Let `model`, `tools`, `skills`, `schema`, `stream`, and `tracer`
  declared with a block be lazily evaluated against the agent instance
  at initialization time, matching how `stream` and `tracer` already
  worked.

  Add `LLM::Agent#params` for direct access to the underlying context
  parameters.

  Ported from mruby-llm.

* **Support `Array[...]` schema and tool param types** <br>
  Let `LLM::Schema` properties and `LLM::Tool` params accept
  `Array[...]` type declarations, including mixed item unions that are
  serialized as `anyOf` array items.

* **Add `LLM::Provider#key?`** <br>
  Add `key?` to providers so callers can check whether a non-blank API
  key has been configured.

* **Add agent tool confirmation hooks** <br>
  Add `LLM::Agent.confirm` and `LLM::Agent#on_tool_confirmation` so
  selected tools can be approved or cancelled before execution. Pending
  tool resolution now relies on `LLM::Context#functions` so confirmed
  tools are not executed twice when mixed with unconfirmed tool calls.

* **Add `LLM::Function#spawn(:call).wait`** <br>
  Add task-shaped sequential execution support for direct
  `LLM::Function#spawn(:call).wait`.

### Fix

* **Reduce private internal methods on `LLM::Stream`** <br>
  Remove `tool_not_found` and `__tools__` from `LLM::Stream`. The
  `__tools__` logic is inlined directly into `__find__` since that
  was its only caller. The `tool_not_found` utility method was unused
  externally and added unnecessary surface to LLM::Stream.

  Ported from mruby-llm.

## v9.0.0

Changes since `v8.1.0`.

This release deepens llm.rb's transport and cost-tracking surface. It
replaces the old mutable `persist!` API with constructor-driven transport
selection, removes `#call` from contexts and agents in favor of explicit
`ctx.wait(:call)`, makes queued stream waits strategy-free, and deletes
the unused `LLM::Utils` module.

It adds cache read/write token tracking
with corresponding cost components, audio and image token pricing,
`LLM::Context#functions?` for queue-aware tool loops,
`LLM::Agent.stream` DSL support, and exposes `#stream` readers on
contexts and agents.

The HTTP transport layer has been refactored around shared backends so
providers, MCP, and custom transports all use the same normalized
response interface.

### Breaking

* **Remove `#call` as a context and agent tool-loop API** <br>
  Remove `LLM::Context#call(:functions)` and `LLM::Agent#call(:functions)`.
  Tool loops should use `ctx.wait(:call)` or `agent.wait(:call)` instead.
  The ActiveRecord and Sequel wrappers no longer expose `#call` passthroughs
  for stored llm.rb contexts.

* **Make HTTP transport selection constructor-driven** <br>
  Remove public `persist!` and `.persistent` mutation APIs from
  providers, transports, and MCP clients. Select persistent behavior at
  construction time with `persistent: true`, `LLM::Transport.net_http`,
  `LLM::Transport.net_http_persistent`, or an explicit `transport:`
  override.

* **Make queued stream waits strategy-free** <br>
  Change `LLM::Stream::Queue#wait` to resolve queued work by the actual
  task types already present in the queue instead of accepting an
  external wait strategy. `LLM::Stream#wait(...)` remains compatible but
  now ignores its arguments when delegating to the queue.

* **Remove unused `LLM::Utils`** <br>
  Delete the `LLM::Utils` module and remove its remaining unused
  provider includes and top-level require.

### Add

* **Expose `#stream` readers on contexts and agents** <br>
  Add public `LLM::Context#stream` and `LLM::Agent#stream` accessors so
  callers can inspect the active stream object directly.

* **Track cache read and write tokens in usage** <br>
  Add `cache_read_tokens` and `cache_write_tokens` to `LLM::Usage` and
  preserve them through completion usage adaptation and context usage
  aggregation.

* **Add `LLM::Context#functions?` for queue-aware tool loops** <br>
  Add `functions?` to `LLM::Context` and the ActiveRecord and Sequel
  wrappers so callers can detect pending tool work through either the
  bound stream queue or unresolved functions, and update the docs to
  prefer `while ctx.functions?` over `ctx.functions.any?` in tool-loop
  examples.

* **Add `:call` as a first-class wait strategy** <br>
  Add `:call` to pending-function wait paths so `ctx.wait(:call)` can
  prefer queued streamed work when present and otherwise fall back to
  direct sequential function execution through `spawn(:call).wait`.

* **Read provider cache usage into completion responses** <br>
  Read cache read tokens from provider usage metadata, including OpenAI
  `usage.prompt_tokens_details` and Anthropic
  `usage.cache_read_input_tokens`. Read Anthropic cache write tokens
  from `usage.cache_creation_input_tokens`, and expose explicit
  zero-valued `cache_write_tokens` methods on providers that do not
  report cache creation usage.

* **Extend cost tracking with cache write pricing** <br>
  Extend `LLM::Cost` with `cache_read_costs`, `cache_write_costs`, and
  `reasoning_costs` alongside the existing `input_costs` and
  `output_costs`. Add `#to_h` for structured cost insight and update
  `ctx.cost` to calculate all available components from registry
  pricing data.

* **Price input and output audio separately** <br>
  Track `input_audio_tokens` and `output_audio_tokens` in usage and
  include `input_audio_costs` and `output_audio_costs` in `LLM::Cost`
  so multimodal requests report accurate audio spend.

* **Track image tokens in input cost reporting** <br>
  Add `input_image_tokens` to usage and include `input_image_costs` in
  `LLM::Cost` using the model's generic input rate so image-bearing
  prompts report their input spend.

* **Add `LLM::Agent.stream` DSL support** <br>
  Let agents define a default `stream` through the class DSL, including
  block-based stream construction so each agent instance can resolve its
  stream the same way `tracer` does.

### Change

* **Refactor HTTP transports around shared backends** <br>
  Split `Net::HTTP` and `Net::HTTP::Persistent` into separate
  `LLM::Transport` implementations, move HTTP-specific request helpers
  and response execution into the shared transport layer, and let MCP
  HTTP wrap those transports instead of maintaining a separate
  transient/persistent client split.

* **Share transport overrides across providers and MCP** <br>
  Let both provider construction and `LLM::MCP.http(...)` accept
  `LLM::Transport` instances or classes as HTTP transport overrides, so
  callers can reuse the same transport implementation across the
  runtime.

* **Let custom transports adapt their own response objects** <br>
  Introduce a transport response interface so custom transports can
  adapt backend-specific response objects to one normalized shape and
  have them work with the existing provider execution and error-handling
  code.

## v8.1.0

Changes since `v8.0.0`.

This release adds Amazon Bedrock provider support through the Converse
API, including AWS SigV4 request signing, event stream decoding,
structured output through `schema:`, and a models.dev-backed registry.
It exposes `llm.models.all` for Bedrock via the ListFoundationModels
API and adds `LLM::Object#transform_values!` for in-place value
transformation. Several Bedrock-specific fixes land as well, including
response id exposure, blank text block suppression in tool turns, and
DSML tool-marker filtering in streamed text.

### Add

* **Add AWS Bedrock provider support** <br>
  Add `LLM.bedrock(...)` with Bedrock Converse chat support, AWS SigV4
  request signing, Bedrock event stream decoding, structured output
  support through `schema:`, and models.dev-backed `bedrock.json`
  registry generation.

* **Add AWS Bedrock Models endpoint support** <br>
  Add `llm.models.all` for Bedrock via the ListFoundationModels API,
  including SigV4 signing for the control-plane endpoint and normalized
  `LLM::Model` collection responses.

* **Add `LLM::Object#transform_values!`** <br>
  Let `LLM::Object` transform stored values in place through
  `#transform_values!`.

### Fix

* **Expose response ids on Bedrock completion responses** <br>
  Read the Bedrock request id into `LLM::Response#id` for completion
  responses adapted from the Converse API.

* **Avoid blank assistant text blocks in Bedrock tool turns** <br>
  Stop replaying assistant tool-call messages with empty text content
  blocks that Bedrock rejects.

* **Suppress Bedrock DSML tool markers in streamed text** <br>
  Filter `"\u003c\u003cDSML\u003efunction_calls\u003e\u003e"` markers out of streamed Bedrock
  assistant text so tool-call sentinels do not leak into user-visible
  output.

## v8.0.0

Changes since `v7.0.0`.

This release adds Unix-fork concurrency for process-isolated tool
execution, extends `LLM::Object` with `#merge` and `#delete`, and drops
Ruby 3.2 support due to a segfault observed with the `:fork` path. It
promotes `LLM::Pipe` to the top-level namespace and adds
`persistent: true` on `LLM::MCP.http` for direct persistent transport
configuration. `LLM::Function#runner` is exposed as public API, agent
tracer overrides are supported, fiber execution now uses `Fiber.schedule`,
missing optional dependencies raise clearer `LLM::LoadError` guidance,
and ActiveRecord wrapper plumbing is deduplicated between `acts_as_llm`
and `acts_as_agent`.

### Breaking

* **Drop Ruby 3.2 support** <br>
  Stop supporting Ruby 3.2 due to a segfault observed with the `:fork`
  tool concurrency strategy.

### Add

* **Add `LLM::Object#merge`** <br>
  Let `LLM::Object` return a new wrapped object when merging hash-like
  data through `#merge`.

* **Add `LLM::Object#delete`** <br>
  Let `LLM::Object` delete keys directly through `#delete`.

### Change

* **Add fork-based tool concurrency** <br>
  Add `:fork` as a new concurrency strategy for `LLM::Function#spawn`,
  `LLM::Function::Array#wait`, and `LLM::Agent.concurrency` that runs
  class-based tools in isolated child processes. Fork-backed tools support
  tracer callbacks, `on_interrupt`/`on_cancel` hooks, and `alive?` checks.
  Requires the `xchan` gem for inter-process communication with `:fork`.
  This is especially useful for tools that need process isolation, such as
  running shell commands or handling unsafe data.

* **Promote `LLM::Pipe` from MCP namespace to top-level** <br>
  Move `LLM::MCP::Pipe` to `LLM::Pipe` so the pipe abstraction is available
  outside MCP internals. The new class adds a `binmode:` option for binary
  pipes. `LLM::MCP::Command` and related MCP transport code have been updated
  to use `LLM::Pipe`.

* **Allow `persistent: true` on `LLM::MCP.http`** <br>
  Let `LLM::MCP.http(...)` enable persistent HTTP transport directly
  through `persistent: true` at construction time.

* **Expose `LLM::Function#runner` as public API** <br>
  Promote the internal runner instantiation to a public `runner` method on
  `LLM::Function`, so callers can inspect or reuse the resolved tool instance
  that a function wraps.

* **Allow agent instance tracer overrides** <br>
  Let `LLM::Agent.new(..., tracer: ...)` override the class-level tracer
  for that agent instance.

* **Make `:fiber` use scheduler-backed fibers** <br>
  Change `:fiber` tool execution to use `Fiber.schedule` and require
  `Fiber.scheduler`, instead of wrapping direct calls in raw fibers. This
  gives `:fiber` a real cooperative concurrency model instead of acting as
  a thin wrapper around sequential execution.

* **Read stored values from zero-argument `LLM::Object` method calls** <br>
  Let calls like `obj.delete`, `obj.fetch`, `obj.merge`, `obj.key?`,
  `obj.dig`, `obj.slice`, or `obj.keys` return a stored value when that
  method name exists as a key and no arguments are given.

* **Harden `LLM::Object` against arbitrary key names** <br>
  Move internal lookup logic off `LLM::Object` instances and onto the
  singleton class instead, making stored keys like `method_missing`
  more resilient while preserving normal dynamic field access.

* **Deduplicate ActiveRecord wrapper plumbing** <br>
  Move shared ActiveRecord wrapper defaults and utility methods into
  `LLM::ActiveRecord`, reducing duplication between `acts_as_llm` and
  `acts_as_agent`.

* **Raise clearer errors for missing optional runtime dependencies** <br>
  Route optional `async`, `xchan`, and `net/http/persistent` loads
  through `LLM.require` so missing runtime gems raise `LLM::LoadError`
  with installation guidance instead of leaking raw `LoadError`
  exceptions.

### Fix

* **Avoid `RuntimeError` from `Async::Task.current` lookups** <br>
  Check `Async::Task.current?` before reading the current Async task so
  provider transports fall back to `Fiber.current` without raising when
  no Async task is active.

* **Serialize `LLM::Object` values correctly through `LLM.json`** <br>
  Make `LLM::Object#to_json` call `LLM.json.dump(to_h, ...)` so
  `LLM::Object` values serialize through the llm.rb JSON adapter.

## v7.0.0

Changes since `v6.1.0`.

This release turns agent tool-loop limit errors into in-band advisory
returns so the LLM can react to rate limits and continue the loop. It
adds `tool_attempts: nil` as a way to opt out of advisory tool-limit
returns entirely, and fixes the default provider HTTP path to keep
`net-http-persistent` optional when not explicitly enabled.

### Breaking

* **Return in-band tool-loop limit errors from agents** <br>
  Stop raising `LLM::ToolLoopError` when an agent exhausts its tool loop
  attempt budget, and instead send advisory `LLM::Function::Return`
  errors back through the model so the LLM can react to the rate limit
  in-band and continue the loop.

* **Allow `tool_attempts: nil` to disable advisory tool-limit returns** <br>
  Keep the default `tool_attempts` budget at `25`, but treat an explicit
  `tool_attempts: nil` as an opt-out that disables advisory tool-limit
  returns entirely.

### Fix

* **Keep `net-http-persistent` optional on normal HTTP requests** <br>
  Stop the default provider HTTP path from loading `net/http/persistent`
  unless persistent transport support is explicitly enabled.

## v6.1.0

Changes since `v6.0.0`.

This release tightens interrupt and compaction behavior for long-running
contexts. It adds `LLM::Buffer#rindex`, supports percentage-based token
thresholds in `LLM::Compactor`, tracks persisted compaction state through
context serialization, reliably interrupts Async-backed requests, preserves
valid tool-call history on cancellation, keeps concurrent skill tool loops
running on streamed agents, and returns zero-valued usage objects when no
provider usage has been recorded yet.

### Change

* **Add `LLM::Buffer#rindex`** <br>
  Add `LLM::Buffer#rindex` as a direct forward to the underlying message
  array so callers can find the last matching message index through the
  buffer API.

* **Support percentage compaction token thresholds** <br>
  Let `LLM::Compactor` accept `token_threshold:` values like `"90%"` so
  compaction can trigger at a percentage of the active model context
  window.

### Fix

* **Interrupt Async-backed requests reliably** <br>
  Track request ownership through the provider transport so contexts use
  the active Async task when available, letting `ctx.interrupt!`
  reliably cancel streamed requests under Async runtimes and surface
  them as `LLM::Interrupt`.

* **Preserve valid tool-call history on cancellation** <br>
  Append cancelled tool-return messages for unresolved tool calls during
  `ctx.interrupt!` so follow-up provider requests do not fail with
  invalid tool-call history after pending tool work is cancelled.

* **Preserve concurrent skill tool loops on streamed agents** <br>
  Propagate the active agent concurrency through the effective request
  stream so nested skill agents keep using queued `wait(...)` tool
  execution instead of falling back to direct `:call` execution.

* **Track persisted compaction state on contexts** <br>
  Mark contexts as compacted after `LLM::Compactor#compact!`, persist and
  restore that state through context serialization, and clear it after the
  next successful model response.

* **Return zero-valued usage objects from contexts** <br>
  Make `LLM::Context#usage` consistently return an `LLM::Object`, using a
  zero-valued usage object when no provider usage has been recorded yet.

## v6.0.0

Changes since `v5.4.0`.

This release simplifies the ORM persistence contract around serialized
`data` state, removing the assumption of reserved `provider`, `model`, and
usage columns. Provider selection must now come from `provider:` hooks,
model defaults come from `context:` or agent DSL, and usage is read from the
serialized runtime state. Alongside this breaking change, Sequel JSON and
JSONB persistence is fixed, ractor-backed tools now fire tracer callbacks,
and `LLM::RactorError` is raised for unsupported ractor tool work.

### Change

* **Simplify ORM persistence to serialized `data` state** <br>
  Change the built-in ActiveRecord and Sequel wrappers to treat serialized
  `data` as the persistence contract, instead of assuming reserved
  `provider`, `model`, and usage columns. Provider selection must now come
  from `provider:` hooks that resolve a real `LLM::Provider` instance, model
  defaults come from `context:` or agent DSL, and `usage` is read from the
  serialized runtime state.

### Fix

* **Fix Sequel JSON and JSONB persistence** <br>
  Load Sequel PostgreSQL JSON support when `plugin :llm` is configured with
  `format: :json` or `:jsonb`, and wrap structured payloads correctly so
  persisted context state can be stored in PostgreSQL JSON columns.

* **Trace ractor-backed tool callbacks** <br>
  Make tool tracers fire `on_tool_start` and `on_tool_finish` for
  class-based `:ractor` execution too, so ractor-backed tool calls show up
  in tracer callbacks like the other concurrent tool paths.

* **Raise `LLM::RactorError` for unsupported ractor tool work** <br>
  Add `LLM::RactorError` and fail fast when `:ractor` execution is requested
  for unsupported tool types such as skill-backed tools, instead of letting
  deeper Ruby isolation errors leak out later in execution.

* **Delegate interrupt to concurrent task implementations** <br>
  Make `LLM::Function::Task#interrupt!` delegate to the underlying fork or
  ractor task when it supports interruption, so `ctx.interrupt!` and
  `task.interrupt!` work correctly for fork- and ractor-backed tool
  execution.

## v5.4.0

Changes since `v5.3.0`.

This release expands tracer support around agentic execution. It lets
`LLM::Agent` define scoped tracers through the agent DSL and fixes concurrent
tool execution so those scoped tracers stay attached when work crosses
thread, task, fiber, and skill boundaries.

### Change

* **Add agent-scoped tracers** <br>
  Let `LLM::Agent` classes define `tracer ...` or `tracer { ... }` so an
  agent can carry its own tracer without replacing the provider's default
  tracer. The resolved tracer is scoped to that agent's turns, tool loops,
  and pending tool access. Available through the `acts_as_agent` and Sequel
  agent plugin `tracer` DSL too.

### Fix

* **Preserve scoped tracers across concurrent tool work** <br>
  Keep agent- and request-scoped tracers attached when tool execution
  crosses `:thread`, `:task`, or `:fiber` boundaries, including skill
  execution, so spawned work does not fall back to the provider default
  tracer.

## v5.3.0

Changes since `v5.2.1`.

This release deepens llm.rb's request-rewriting and tool-definition surface.
It adds transformer lifecycle hooks to `LLM::Stream` so UIs can surface work
like PII scrubbing before a request is sent, and it adds a more explicit
OmniAI-style tool DSL form with `parameter` plus separate `required`
declarations while keeping the older `param ... required: true` style working.

### Change

* **Add transformer stream lifecycle hooks** <br>
  Add `on_transform` and `on_transform_finish` to
  `LLM::Stream` so UIs can surface request rewriting work such as PII
  scrubbing before a request is sent to the model.

* **Add a separate `required` tool DSL form** <br>
  Add `parameter` as an alias of `param` and support `required %i[...]`
  as a separate declaration, inspired by OmniAI-style tools, while keeping
  the existing `param ... required: true` form working too.

## v5.2.1

Changes since `v5.2.0`.

This release tightens the streamed queue fix from `v5.2.0` for concurrent
workloads. Request-local streams now stay bound long enough for `wait` to
drain queued work and then clear cleanly so later waits fall back to the
context's configured stream.

### Fix

* **Reset request-local streams after `wait` drains queued work** <br>
  Keep per-call `stream:` bindings alive through `LLM::Context#wait` so
  queued streamed tool work still resolves correctly, then clear the
  request-local stream after the wait completes to avoid leaking it into
  later turns.

## v5.2.0

Changes since `v5.1.0`.

This release adds current DeepSeek V4 support through refreshed provider
metadata, including `deepseek-v4-flash` and `deepseek-v4-pro`, while fixing
request-local queue handling for concurrent streamed workloads so `wait` and
interruption use the active per-call stream correctly.

### Change

* **Add `LLM::MCP#run` for scoped MCP client lifecycle** <br>
  Add `LLM::MCP#run` so MCP clients can be started for the duration of a
  block and then stopped automatically, which simplifies the usual
  `start`/`stop` pattern in examples and application code.

* **Refresh provider model metadata** <br>
  Add current DeepSeek and OpenAI model metadata to `data/` and update the
  Google Gemini model entry to match the current provider naming.

### Fix

* **Reject unsupported DeepSeek multimodal prompt objects early** <br>
  Raise `LLM::PromptError` for `image_url`, `local_file`, and
  `remote_file` in DeepSeek chat requests instead of sending invalid
  OpenAI-compatible payloads that the provider rejects at runtime.

* **Preserve DeepSeek reasoning content across tool turns** <br>
  Replay `reasoning_content` when serializing prior assistant messages for
  DeepSeek chat completions, so thinking-mode tool calls can continue into
  follow-up requests without triggering invalid request errors.

* **Default DeepSeek to `deepseek-v4-flash`** <br>
  Change `LLM::DeepSeek#default_model` to `deepseek-v4-flash` so new
  contexts and default provider usage align with the current preferred chat
  model.

* **Use per-call streams when waiting on streamed tool work** <br>
  Track request-local streams bound through `talk(..., stream:)` and
  `respond(..., stream:)` so `LLM::Context#wait` and interruption-aware
  queue handling use the active stream instead of falling back to pending
  function spawning.

## v5.1.0

Changes since `v5.0.0`.

This release tightens streamed tool execution around the actual request-local
runtime state. It fixes streamed resolution of per-request tools and makes
that streamed path work cleanly with `LLM.function(...)`, MCP tools, bound
tool instances, and normal tool classes.

### Fix

* **Resolve request-local tools during streaming** <br>
  Resolve streamed tool calls through `LLM::Stream` request-local tools
  before falling back to the global registry, so per-request tools and bound
  tool instances work correctly during streaming.

* **Support `LLM.function(...)` and MCP tools in streamed tool resolution** <br>
  Let streamed tool resolution use the current request tool set, so
  `LLM.function(...)`, MCP tools, bound tool instances, and normal
  `LLM::Tool` classes all work through the same streamed tool path.

## v5.0.0

Changes since `v4.23.0`.

This release expands llm.rb from an execution runtime into a more explicit
supervision and transformation runtime. It adds context-level guards,
transformers, and loop supervision through `LLM::LoopGuard`, while deepening
long-lived context behavior through compaction, interruption hooks, and
streamed `ctx.spawn(...)` tool execution.

### Change

* **Make compactor thresholds explicit** <br>
  Require `message_threshold:` and `token_threshold:` to be opted into
  explicitly, so `LLM::Compactor` only compacts automatically when one of
  those thresholds is configured. Context-window-derived token limits can be
  computed by the caller when needed.

* **Allow assigning a compactor through `LLM::Context`** <br>
  Let `LLM::Context` accept `ctx.compactor = ...` in addition to the
  constructor `compactor:` option, so compactor config can be assigned or
  replaced after context initialization.

* **Mark compaction summaries in message metadata** <br>
  Mark compaction summaries with `extra[:compaction]` and
  `LLM::Message#compaction?`, so applications can detect or hide synthetic
  summary messages in conversation history.

* **Add cooperative tool interruption hooks** <br>
  Let `ctx.interrupt!` notify queued tool work through `on_interrupt`, so
  running tools can clean up cooperatively when a context is cancelled.

* **Add `LLM::Context` guards** <br>
  Add a new `guard` capability to `LLM::Context` so execution can be
  supervised at the runtime level. The built-in `LLM::LoopGuard` detects
  repeated tool-call patterns and stops stuck agentic loops through in-band
  `LLM::GuardError` returns. `LLM::Agent` enables this guard by default.

* **Add `LLM::Context` transformers** <br>
  Add a new `transformer` capability to `LLM::Context` so prompts and params
  can be rewritten before provider requests are sent. This makes it possible
  to apply context-wide behaviors such as PII scrubbing or request-level
  param injection without rewriting every `talk` and `respond` call site.

## v4.23.0

Changes since `v4.22.0`.

This release expands llm.rb's runtime surface for long-lived contexts and
stateful tools. It adds built-in context compaction through `LLM::Compactor`,
lets explicit `tools:` arrays accept bound `LLM::Tool` instances, and fixes
OpenAI-compatible no-arg tool schemas for stricter providers such as xAI.

### Change

* **Add `LLM::Compactor` for long-lived contexts** <br>
  Add built-in context compaction through `LLM::Compactor`, so older history
  can be summarized, retained windows can stay bounded, compaction can run on
  its own `model:`, thresholds can be configured explicitly, and
  `LLM::Stream` can observe the lifecycle through `on_compaction` and
  `on_compaction_finish`.

* **Allow bound tool instances in explicit tool lists** <br>
  Let explicit `tools:` arrays accept `LLM::Tool` instances such as
  `MyTool.new(foo: 1)`, so tools can carry bound state without changing the
  global tool registry model.

### Fix

* **Fix xAI/OpenAI-compatible no-arg tool schemas** <br>
  Send an empty object schema for tools without declared parameters instead
  of `null`, so stricter providers such as xAI accept mixed tool sets that
  include no-arg tools.

## v4.22.0

Changes since `v4.21.0`.

This release deepens the runtime shape of llm.rb. It reduces helper-method
surface on persisted ORM models, expands real ORM coverage, and makes skills
behave more like bounded sub-agents with inherited recent context and proper
instruction injection.

### Change

* **Reduce ActiveRecord wrapper model surface** <br>
  Move helper methods such as option resolution, column mapping,
  serialization, and persistence into `Utils` for the ActiveRecord
  wrappers so wrapped models include fewer internal helper methods.

* **Reduce Sequel wrapper model surface** <br>
  Move helper methods such as option resolution, column mapping,
  serialization, and persistence into `Utils` for the Sequel wrappers
  so wrapped models include fewer internal helper methods.

* **Expand ORM integration coverage** <br>
  Add broader ActiveRecord and Sequel coverage for persisted context and
  agent wrappers, including real SQLite-backed records and cassette-backed
  OpenAI persistence paths.

* **Make skills inherit recent parent context** <br>
  Run `LLM::Skill` with a curated slice of recent parent user and assistant
  messages, prefixed with `Recent context:`, so skills behave more like
  task-scoped sub-agents instead of instruction-only helpers.

### Fix

* **Fix Sequel `plugin :agent` load order** <br>
  Require the shared Sequel plugin support from `LLM::Sequel::Agent` so
  `plugin :agent` can load independently without raising
  `uninitialized constant LLM::Sequel::Plugin`.

* **Make skill execution inherit parent context request settings** <br>
  Run `LLM::Skill` through a parent `LLM::Context` instead of a bare
  provider so nested skill agents inherit context-level settings such as
  `mode: :responses`, `store: false`, streaming, and other request defaults,
  while still keeping skill-local tools and avoiding parent schemas.

* **Keep agent instructions when history is preseeded** <br>
  Inject `LLM::Agent` instructions once unless a system message is already
  present, so agents and nested skills still get their instructions when
  they start with inherited non-system context.

## v4.21.0

Changes since `v4.20.2`.

This release expands higher-level composition in llm.rb. It adds Sequel agent
persistence through `plugin :agent` and introduces directory-backed skills
that load from `SKILL.md`, resolve named tools, and plug directly into
`LLM::Context` and `LLM::Agent`.

### Change

* **Add `plugin :agent` for Sequel models** <br>
  Add Sequel support for `plugin :agent`, similar to ActiveRecord's
  `acts_as_agent`, so models can wrap `LLM::Agent` with built-in
  persistence.

* **Load directory-backed skills through `LLM::Context` and `LLM::Agent`** <br>
  Add `skills:` to `LLM::Context` and `skills ...` to `LLM::Agent` so
  directories with `SKILL.md` can be loaded, resolved into tools, and run
  through the normal llm.rb tool path.

## v4.20.2

Changes since `v4.20.1`.

This patch release improves runtime behavior around interruption and mixed
concurrency waits. It also rounds out response API uniformity for Google
completion responses.

### Fix

* **Expose Google completion response IDs through `.id`** <br>
  Add `LLM::Response#id` support to Google completion responses so tracer
  and caller code can rely on the same API used by other providers.

* **Track interrupt ownership on the active request** <br>
  Bind `LLM::Context` interruption to the fiber running `talk` or `respond`
  so `interrupt!` works correctly when requests are started outside the
  context's initialization fiber.

### Change

* **Allow mixed concurrency strategies in `wait(...)`** <br>
  Let `LLM::Context#wait`, `LLM::Stream#wait`, and `LLM::Agent.concurrency`
  accept arrays such as `[:thread, :ractor]` so mixed tool sets can wait on
  more than one concurrency strategy.

## v4.20.1

Changes since `v4.20.0`.

This patch release fixes ORM option resolution in the Sequel and
ActiveRecord wrappers. Symbol-based `provider:` and `context:` hooks now
resolve correctly, and internal default option constants are referenced
explicitly instead of relying on nested constant lookup.

### Fix

* **Fix symbol-based ORM option hooks for provider and context hashes** <br>
  Make `provider:` and `context:` resolve symbol hooks through the model in
  the Sequel plugin and ActiveRecord wrappers instead of falling back to an
  empty hash.

* **Fix ORM wrapper constant lookup for option defaults** <br>
  Qualify internal `EMPTY_HASH` / `DEFAULTS` references in the Sequel plugin
  and ActiveRecord wrappers so option resolution does not depend on nested
  constant lookup quirks.

## v4.20.0

Changes since `v4.19.0`.

This release adds better support for tagged prompt content. `LLM::Context`
can now serialize and restore `image_url`, `local_file`, and `remote_file`
content cleanly, and `LLM::Message` now exposes helpers for inspecting
tagged image and file attachments.

### Change

* **Round-trip tagged prompt objects through `LLM::Context`** <br>
  Teach `LLM::Context` serialization and restore to preserve
  `image_url`, `local_file`, and `remote_file` content across
  `to_json` / `restore`.

* **Add attachment helpers to `LLM::Message`** <br>
  Add `image_url?`, `image_urls`, `file?`, and `files` so callers can
  inspect messages for tagged image and file content more directly.

## v4.19.0

Changes since `v4.18.0`.

This release tightens the ActiveRecord and ORM integration layer. It adds
inline agent DSL blocks to `acts_as_agent` so agent defaults can be defined
where the wrapper is declared, and it exposes the resolved provider through
public `llm` methods on the ActiveRecord and Sequel wrappers.

### Change

* **Make ORM provider access public through `llm`** <br>
  Expose the resolved provider on the Sequel plugin and the ActiveRecord
  `acts_as_llm` / `acts_as_agent` wrappers through a public `llm` method.

* **Allow inline agent DSL blocks in `acts_as_agent`** <br>
  Let ActiveRecord models configure `model`, `tools`, `schema`,
  `instructions`, and `concurrency` directly inside the `acts_as_agent`
  declaration block.

## v4.18.0

Changes since `v4.17.0`.

This release improves tracing and tool execution behavior across llm.rb.
It makes provider tracers default to the provider instance, adds
`LLM::Provider#with_tracer` for scoped overrides, restores tool tracing for
concurrent and streamed tool execution, extends streamed tracing to MCP tools,
and adds symbol-based ORM option hooks alongside experimental ractor tool
concurrency.

### Change

* **Make provider tracers default to the provider instance** <br>
  Change `llm.tracer = ...` so it sets a provider default tracer instead of
  relying on scoped fiber-local state alone. This makes tracer configuration
  behave more predictably across normal tasks, threads, and fibers that share
  the same provider instance.

* **Add `LLM::Provider#with_tracer` for scoped overrides** <br>
  Add `with_tracer` as the opt-in escape hatch for request- or turn-scoped
  tracer overrides. Use it when you want temporary tracing on the current
  fiber without replacing the provider's default tracer.

* **Trace concurrent tool calls outside ractors** <br>
  Make tool tracing fire correctly when functions run through `:thread`,
  `:task`, or `:fiber` concurrency. Experimental `:ractor` execution still
  does not emit tool tracer events.

* **Trace streamed tool calls, including MCP tools** <br>
  Bind stream metadata through `LLM::Stream#extra` so streamed tool calls
  inherit tracer and model context before they are handed to `on_tool_call`.
  This restores tool tracing for streamed MCP and local tool execution.

* **Support symbol-based ORM option hooks** <br>
  Let `provider:`, `context:`, and `tracer:` on the Sequel plugin and
  the ActiveRecord `acts_as_llm` / `acts_as_agent` wrappers resolve through
  model method names as well as procs.

* **Add experimental ractor tool concurrency** <br>
  Add `:ractor` support to `LLM::Function#spawn`, `LLM::Function::Array#wait`,
  `LLM::Stream#wait`, and `LLM::Agent.concurrency` so class-based tools with
  ractor-safe arguments and return values can run in Ruby ractors and report
  their results back into the normal LLM tool-return path. MCP tools are not
  supported by the current `:ractor` mode, but mixed workloads can still
  branch on `tool.mcp?` and choose a supported strategy per tool. `:ractor`
  is especially useful for CPU-bound tools, while `:task`, `:fiber`, or
  `:thread` may be a better fit for I/O-bound work.

## v4.17.0

Changes since `v4.16.1`.

This release expands agent support across llm.rb. It brings `LLM::Agent`
closer to `LLM::Context`, adds configurable automatic tool concurrency
including experimental ractor support for class-based tools,
extends persisted ORM wrappers with more of the context runtime surface and
tracer hooks, and introduces built-in ActiveRecord agent persistence through
`acts_as_agent`.

### Change

* **Add configurable tool concurrency to `LLM::Agent`** <br>
  Add the class-level `concurrency` DSL to `LLM::Agent` so automatic
  tool loops can run with `:call`, `:thread`, `:task`, `:fiber`, or
  experimental `:ractor` support for class-based tools instead of
  always executing sequentially.

* **Bring `LLM::Agent` closer to `LLM::Context`** <br>
  Expand `LLM::Agent` so it exposes more of the same runtime surface as
  `LLM::Context`, including returns, interruption, mode, cost, context
  window, structured serialization, and other context-backed helpers,
  while still auto-managing tool loops.

* **Refresh agent docs and coverage** <br>
  Update the README and deep dive to explain the current role of
  `LLM::Agent`, add examples that show automatic tool execution and
  concurrency, and add focused specs for the expanded agent surface and
  tool-loop behavior.

* **Add ORM tracer hooks for persisted contexts** <br>
  Add `tracer:` to both the Sequel plugin and `acts_as_llm` so models
  can resolve and assign tracers onto the provider used by their persisted
  `LLM::Context`.

* **Bring persisted ORM wrappers closer to `LLM::Context`** <br>
  Expand both the Sequel plugin and `acts_as_llm` so record-backed
  contexts expose more of the same runtime surface as `LLM::Context`,
  including mode, returns, interruption, prompt helpers, file helpers,
  and tracer access.

* **Add ActiveRecord agent persistence with `acts_as_agent`** <br>
  Add `acts_as_agent` for ActiveRecord models that should wrap
  `LLM::Agent`, reusing the same record-backed runtime shape as
  `acts_as_llm` while letting tool execution be managed by the agent.

## v4.16.1

Changes since `v4.16.0`.

This release tightens ORM persistence by removing an unnecessary JSON
round-trip when restoring structured `:json` and `:jsonb` context
payloads.

### Change

* **Restore structured ORM payloads directly** <br>
  Teach `LLM::Context#restore` to accept parsed data payloads and use
  that path from the ActiveRecord and Sequel persistence wrappers for
  `format: :json` and `:jsonb`, avoiding a redundant
  `Hash -> JSON string -> Hash` round-trip on restore.

## v4.16.0

Changes since `v4.15.0`.

This release expands ORM support with built-in ActiveRecord persistence
and improves compatibility with OpenAI-compatible gateways, proxies, and
self-hosted servers that use non-standard API root paths.

### Change

* **Support OpenAI-compatible base paths** <br>
  Add `base_path:` to provider configuration so OpenAI-compatible
  endpoints can vary both host and API prefix. This supports providers,
  proxies, and gateways that keep OpenAI request shapes but use
  non-standard URL layouts such as DeepInfra's `/v1/openai/...`.

* **Add ActiveRecord context persistence with `acts_as_llm`** <br>
  Add a built-in ActiveRecord wrapper that mirrors the Sequel plugin
  API so applications can persist `LLM::Context` state on records with
  default columns, provider/context hooks, validation-backed writes,
  and `format: :string`, `:json`, or `:jsonb` storage.

## v4.15.0

Changes since `v4.14.0`.

### Change

* **Reduce OpenAI stream parser merge overhead** <br>
  Special-case the most common single-field deltas, streamline
  incremental tool-call merging, and avoid repeated JSON parse attempts
  until streamed tool arguments look complete.

* **Cache streaming callback capabilities in parsers** <br>
  Cache callback support checks once at parser initialization time in
  the OpenAI, OpenAI Responses, Anthropic, Google, and Ollama stream
  parsers instead of repeating `respond_to?` checks on hot streaming
  paths.

* **Reduce OpenAI Responses parser lookup overhead** <br>
  Special-case the hot Responses API event paths and cache the current
  output item and content part so streamed output text deltas do less
  repeated nested lookup work.

* **Add a Sequel context persistence plugin** <br>
  Add `plugin :llm` for Sequel models so apps can persist
  `LLM::Context` state with default columns and pass provider setup
  through `provider:` when needed. The plugin now also supports
  `format: :string`, `:json`, or `:jsonb` for text and native JSON
  storage when Sequel JSON typecasting is enabled.

* **Improve streaming parser performance** <br>
  In the local replay-based `stream_parser` benchmark versus `v4.14.0`
  (median of 20 samples, 5000 iterations), plain Ruby is a
  small overall win: the generic eventstream path is about 0.4%
  faster, the OpenAI stream parser is about 0.5% faster, and the
  OpenAI Responses parser is about 1.6% faster, with unchanged
  allocations. Under YJIT on the same benchmark harness, the generic
  eventstream path is about 0.9% faster and the OpenAI stream parser
  is about 0.4% faster, while the OpenAI Responses parser is about
  0.7% slower, also with unchanged allocations.

  Compared to `v4.13.0`, the larger `v4.14.0` streaming gains still
  hold. The generic eventstream path remains dramatically faster than
  `v4.13.0`, the OpenAI stream parser remains modestly faster, and the
  OpenAI Responses parser is roughly flat to slightly better depending
  on runtime. In other words, current keeps the large eventstream win
  from `v4.14.0`, adds only small incremental changes beyond that, and
  does not turn the post-`v4.14.0` parser work into another large
  benchmark jump.

## v4.14.0

Changes since `v4.13.0`.

This release adds request interruption for contexts, reworks provider
HTTP internals for lower-overhead streaming, and fixes MCP clients so
parallel tool calls can safely share one connection.

### Add

* **Add request interruption support** <br>
  Add `LLM::Context#interrupt!`, `LLM::Context#cancel!`, and
  `LLM::Interrupt` for interrupting in-flight provider requests,
  inspired by Go's context cancellation.

### Change

* **Rework provider HTTP transport internals** <br>
  Rework provider HTTP around `LLM::Provider::Transport::HTTP` with
  explicit transient and persistent transport handling.

* **Reduce SSE parser overhead** <br>
  Dispatch raw parsed values to registered visitors instead of building
  an `Event` object for every streamed line.

* **Reduce provider streaming allocations** <br>
  Decode streamed provider payloads directly in
  `LLM::Provider::Transport::HTTP` before handing them to provider
  parsers, which cuts allocation churn and gives a small streaming
  speed bump.

* **Reduce generic SSE parser allocations** <br>
  Keep unread event-stream buffer data in place until compaction is
  worthwhile, which lowers allocation churn in the remaining generic
  SSE path.

* **Improve streaming parser performance** <br>
  In the local replay-based `stream_parser` benchmark versus `v4.13.0`
  (median of 20 samples, 5000 iterations):
  Plain Ruby: the generic eventstream path is about 53% faster with
  about 32% fewer allocations, the OpenAI stream parser is about 11%
  faster with about 4% fewer allocations, and the OpenAI Responses
  parser is about 3% faster with unchanged allocations.
  YJIT on the current parser benchmark harness: the current tree is
  about 26% faster than non-YJIT on the generic eventstream path,
  about 18% faster on the OpenAI stream parser, and about 16% faster
  on the OpenAI Responses parser, with allocations unchanged.

### Fix

* **Support parallel MCP tool calls on one client** <br>
  Route MCP responses by JSON-RPC id so concurrent tool calls can
  share one client and transport without mismatching replies.

* **Use explicit MCP non-blocking read errors** <br>
  Use `IO::EAGAINWaitReadable` while continuing to retry on
  `IO::WaitReadable`.

## v4.13.0

Changes since `v4.12.0`.

This release expands MCP prompt support, improves reasoning support in the
OpenAI Responses API, and refreshes the docs around llm.rb's runtime model,
contexts, and advanced workflows.

### Add

- Add `LLM::MCP#prompts` and `LLM::MCP#find_prompt` for MCP prompt support.

### Change

- Rework the README around llm.rb as a runtime for AI systems.
- Add a dedicated deep dive guide for providers, contexts, persistence,
  tools, agents, MCP, tracing, multimodal prompts, and retrieval.

### Fix

All of these fixes apply to MCP:

- fix(mcp): raise `LLM::MCP::MismatchError` on mismatched response ids.
- fix(mcp): normalize prompt message content while preserving the original payload.

All of these fixes apply to OpenAI's Responses API:

- fix(openai): emit `on_reasoning_content` for streamed reasoning summaries.
- fix(openai): skip `previous_response_id` on `store: false` follow-up calls.
- fix(openai): fall back to an empty object schema for tools without params.
- fix(openai): preserve original tool-call payloads on re-sent assistant tool messages.
- fix(openai): emit `output_text` for assistant-authored response content.
- fix(openai): return `nil` for `system_fingerprint` on normalized response objects.

## v4.12.0

Changes since `v4.11.1`.

This release expands advanced streaming and MCP execution while reframing
llm.rb more clearly as a system integration layer for LLMs, tools, MCP
sources, and application APIs.

### Add

- Add `persistent` as an alias for `persist!` on providers and MCP transports.
- Add `LLM::Stream#on_tool_return` for observing completed streamed tool work.
- Add `LLM::Function::Return#error?`.

### Change

- Expect advanced streaming callbacks to use `LLM::Stream` subclasses
  instead of duck-typing them onto arbitrary objects. Basic `#<<`
  streaming remains supported.

### Fix

- Fix Anthropic tools without params by always emitting `input_schema`.
- Fix Anthropic tool-only responses to still produce an assistant message.
- Fix Anthropic tool results to use the `user` role.
- Fix Anthropic tool input normalization.

## v4.11.1

Changes since `v4.11.0`.

### Fix

* Cast OpenTelemetry tool-related values to strings. <br>
  Otherwise they're rejected by opentelemetry-sdk as invalid attributes.

## v4.11.0

Changes since `v4.10.0`.

### Add

- Add `LLM::Stream` for richer streaming callbacks, including `on_content`,
  `on_reasoning_content`, and `on_tool_call` for concurrent tool execution.
- Add `LLM::Stream#wait` as a shortcut for `queue.wait`.
- Add `LLM::Context#wait` as a shortcut for the configured stream's `wait`.
- Add `LLM::Context#call(:functions)` as a shortcut for `functions.call`.
- Add `LLM::Function.registry` and enhanced support for MCP tools in
  `LLM::Tool.registry` for tool resolution during streaming.
- Add normalized `LLM::Response` for OpenAI Responses, providing `content`,
  `content!`, `messages` / `choices`, `usage`, and `reasoning_content`.
- Add `mode: :responses` to `LLM::Context` for routing `talk` through the
  Responses API.
- Add `LLM::Context#returns` for collecting pending tool returns from the context.
- Add persistent HTTP connection pooling for repeated MCP tool calls via
  `LLM.mcp(http: ...).persist!`.
- Add explicit MCP transport constructors via `LLM::MCP.stdio(...)` and
  `LLM::MCP.http(...)`.

### Fix

- Fix Google tool-call handling by synthesizing stable ids when Gemini does
  not provide a direct tool-call id.

## v4.10.0

Changes since `v4.9.0`.

### Add

- Add HTTP transport for MCP with `LLM::MCP::Transport::HTTP` for remote servers
- Add JSON Schema union types (`any_of`, `all_of`, `one_of`) with parser integration
- Add JSON Schema type array union support (e.g., `"type": ["object", "null"]`)
- Add JSON Schema type inference from `const`, `enum`, or `default` fields

### Change

- Update `LLM::MCP` constructor for exclusive `http:` or `stdio:` transport
- Update `LLM::MCP` documentation for HTTP transport support

## v4.9.0

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
- `README and screencast refresh across `#66`, `#68`, `#71`, and
  `#72`
- `chore(bot): update deprecation warning from v5.0 to v6.0`
- `fix(deepseek): tolerate malformed tool arguments`
- `refactor(context): Rename Session as Context (#70)`

Comparison base:
- Latest tag: `v4.8.0` (`6468f2426ee125823b7ae43b4af507b125f96ffc`)
- HEAD used for this changelog: `915c48da6fda9bef1554ff613947a6ce26d382e3`
