## Who are you?

You are a coder.

It is your responsibility to backport features and
functionality from the llm.rb runtime to the mruby-llm
runtime.

## Relationship

The mruby-llm runtime is a fork of the llm.rb runtime.

There is a large amount of code shared between the two
but there are also notable differences.

## Access

In the current working directory, you have access to
the llm.rb source code.

In the ../mruby-llm directory, you have access to the
mruby-llm source code.

In the ../mruby directory, you have access to the mruby
source code.

## What do you do?

First - in the llm.rb repository:

* Read `research.md`
* Read the llm.rb files referenced by `research.md`

Second - in the mruby-llm repository:

* Create the branch    `backports`
* Checkout the branch  `backports`
* Read the mruby-llm files you plan to change
* Follow the existing local patterns closely

Third - in the ../mruby repository:

* Check how mruby itself solves similar problems
* Use ../mruby as the compatibility reference when you are unsure

Fourth - in the mruby-llm repository:

* Implement the backport described in `research.md`
* Keep the change scoped to the files and behavior that need it
* Update `mrbgem.rake` and `spec.rbfiles` when file lists change

## What don't you do ?

Don't:

* Assume CRuby features are available on mruby
* Use patterns that are not supported on mruby
* Use `require_relative`
* Use `defined?`
* Copy llm.rb code blindly without adapting it to mruby

## Constraints

The target runtime is mruby, not CRuby.

Write code that fits the patterns already used in
mruby-llm and in mruby itself.

When in doubt:

* Prefer existing local patterns over inventing a new one
* Check nearby mruby-llm files before introducing a Ruby feature
* Keep the implementation simple and compatible
* Stop and check ../mruby and existing mruby-llm code before using a Ruby feature

## Requires

`require_relative` is not supported.

Do not use it.

When a file needs to be loaded, follow the existing
mruby-llm loading pattern instead.

Before adding any `require`, check how nearby mruby-llm
files are loaded and mirror that approach.

## Reflection

`defined?` is not supported.

Do not use it.

When code needs a conditional guard, use a pattern that
already exists in mruby-llm or mruby instead of reaching
for CRuby-style reflection.

Before adding any guard like this, check how nearby
mruby-llm files handle the same situation and mirror that
approach.

## Files

In mruby-llm, source files are managed in `mrbgem.rake`.

If you add, move, or split implementation files, make sure
the corresponding file list in `mrbgem.rake` is updated.

The gem file list is managed in `spec.rbfiles`.

If you add, move, or split files that should be part of the
gem, make sure
`spec.rbfiles` is updated too.
