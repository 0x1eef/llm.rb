
## Built-in tools

### Introduction

#### Overview

llm.rb ships with twelve ready-made tools that cover the operations
a coding or system agent needs most: filesystem work, search, and
shell commands. Each tool is a subclass of
[`LLM::Tool`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html)
with a name, description, and typed parameters, exactly like a tool
you would write yourself. Load the whole catalog with
`require "llm/tools"`.

#### How it works

When you want to attach every built-in tool to an agent, require
the catalog and pass the full set of subclasses as the `tools:`
option. The runtime registers each tool's schema and lets the model
decide when to call it.

```ruby
require "llm"
require "llm/tools"

llm   = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, tools: LLM::Tool.subclasses)
agent.talk "List the files in this repository"
```

#### Why would I use it?

The built-in tools cover the operations a coding or system agent
needs most, so you rarely need to write your own. They also handle
edge cases correctly: subprocesses get timeouts, interrupts kill
the child process, and failed calls return structured errors
instead of crashing the conversation.

#### Notes

The tools that spawn subprocesses use the optional `test-cmd.rb`
gem for process management and interrupt handling. The gem is
required only when those tools load. Every tool returns a Hash with
an `ok:` key that tells the model whether the call succeeded.

### Filesystem

#### Overview

The filesystem tools let the model read, write, and edit files,
list and create directories, and move around the working tree.
The most distinctive is
[`LLM::Tool::EditFile`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/EditFile.html),
which replaces an exact snippet and verifies the match count:

```ruby
LLM::Tool::EditFile.new.call(
  path: "config.yml",
  before: "port: 3000",
  after:  "port: 4000"
)
# => {ok: true, replaced: 1}
```

#### How it works

Each filesystem tool takes a path and returns a result Hash. The
`read-file` tool reads a whole file by default and accepts `start:`
and `stop:` to read a range of lines instead. The `edit-file` tool
counts occurrences of `before` and raises unless the count matches
`expected_count`, which defaults to 1.

| Tool | Name | Parameters | Purpose |
|---|---|---|---|
| [`LLM::Tool::Pwd`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Pwd.html) | `pwd` | none | Report the current working directory |
| [`LLM::Tool::Ls`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Ls.html) | `ls` | `path`, `glob` | List files and directories, optionally matching a glob |
| [`LLM::Tool::Chdir`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Chdir.html) | `chdir` | `path` | Change the current working directory |
| [`LLM::Tool::Mkdir`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Mkdir.html) | `mkdir` | `path` | Create a tree of directories |
| [`LLM::Tool::ReadFile`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/ReadFile.html) | `read-file` | `path`, `start`, `stop` | Read a file, optionally a range of lines |
| [`LLM::Tool::WriteFile`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/WriteFile.html) | `write-file` | `path`, `content` | Write a string to a file |
| [`LLM::Tool::EditFile`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/EditFile.html) | `edit-file` | `path`, `before`, `after`, `expected_count` | Replace an exact snippet in a file |

#### Why would I use it?

Reading source files to answer questions, writing new files, and
editing a snippet in place are the bread and butter of a coding
agent. The filesystem tools give the model all of it without you
writing a single tool.

#### Notes

The `chdir` tool changes the working directory for the whole
process, so subsequent file operations see the new directory. The
`mkdir` tool creates parent directories, like `mkdir -p`. The `ls`
tool raises when the path does not exist.

### Search

#### Overview

The search tools find things without reading the whole tree: `rg`
searches file contents, and `which` locates an executable on the
PATH. When a method name or a term is needed, the model searches
for it instead of guessing.

```ruby
LLM::Tool::Rg.new.call(patterns: ["def talk"], path: "lib")
# => {ok: true, stdout: "lib/llm/context.rb:42:def talk", stderr: ""}
```

#### How it works

When you want to search for one or more patterns, call the
[`LLM::Tool::Rg#call`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Rg.html#call-instance_method)
method with an Array of patterns, an optional `path:`, and a
`timeout:` in seconds. When you want to check whether a command is
installed, call the
[`LLM::Tool::Which#call`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Which.html#call-instance_method)
method with a `name:`.

| Tool | Name | Parameters | Purpose |
|---|---|---|---|
| [`LLM::Tool::Rg`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Rg.html) | `rg` | `patterns`, `path`, `timeout` | Recursively search for lines matching patterns |
| [`LLM::Tool::Which`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Which.html) | `which` | `name` | Locate an executable on the system PATH |

#### Why would I use it?

Search is how the model finds something without scanning files one
by one. Asked where a method is defined, the agent searches for it.
Before running a command, it checks with `which` that the binary
exists, and falls back to another approach when it does not.

#### Notes

The `rg` tool runs the ripgrep binary, so `rg` must be installed
and on the PATH. It refuses to search from the filesystem root and
rejects the pattern `.` to keep the model from dumping the entire
tree in one call. The `which` tool is pure Ruby: it scans the PATH
in order and returns the first directory that contains an
executable with the given name. When no match is found it returns
`{ok: false, path: nil}`.

### Shell

#### Overview

The shell tools run real subprocesses: arbitrary commands through
`shell`, Ruby code through `ruby`, and a fixed set of git actions
through `git`. All three accept a `timeout:` and kill the child
process when the model interrupts the turn.

```ruby
LLM::Tool::Shell.new.call(
  name: "bundle",
  arguments: ["exec", "rspec", "spec/llm"],
  timeout: 30
)
```

#### How it works

When you want to run a command and capture its output, call the
[`LLM::Tool::Shell#call`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Shell.html#call-instance_method)
method with a `name:` and optional `arguments:`. The `git` tool
accepts an `action:` from a fixed set, and the `ruby` tool runs its
code in a fresh process.

| Tool | Name | Parameters | Purpose |
|---|---|---|---|
| [`LLM::Tool::Shell`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Shell.html) | `shell` | `name`, `arguments`, `timeout` | Run a shell command |
| [`LLM::Tool::Git`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Git.html) | `git` | `action`, `arguments`, `timeout` | Run a fixed set of git actions |
| [`LLM::Tool::Ruby`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Ruby.html) | `ruby` | `code`, `timeout` | Run a string of Ruby code |

#### Why would I use it?

Running tests, inspecting git history, and executing a snippet of
Ruby are things a coding agent needs to do. The shell tools make
those actions first-class, and the timeout keeps a hanging command
from stalling the conversation.

#### Notes

[`LLM::Tool::Shell`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Shell.html)
can be dangerous given a low-quality model. Gate it behind
[`LLM::Agent#confirm`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#confirm)
or manage the tool loop manually through
[`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html).
On interrupt, the running child process is killed. The `ruby` tool
uses the same Ruby that launched llm.rb. The `git` tool wraps the
actions `log`, `diff`, `commit`, `checkout`, `branch`, and `show`.
