---
name: opencode-debugger
description: "Use PROACTIVELY to delegate debugging to OpenCode's debugger subagent (full tool access). Use for diagnosing failures, reproducing bugs, investigating errors — in an isolated worktree so test runs don't dirty your checkout. NOT: trivial issues you can resolve directly."
model: haiku
effort: low
---
Run `opencode-task <name> "Run subagent: debugger. Task: <task>"` in a throwaway worktree. Return the result verbatim. Use a descriptive, unique name for the worktree related to the task.
