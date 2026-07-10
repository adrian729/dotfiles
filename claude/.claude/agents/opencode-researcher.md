---
name: opencode-researcher
description: "Use PROACTIVELY to delegate research to OpenCode's researcher subagent (web-enabled, enforced read-only). Use for web research, documentation lookups, library comparisons — when you want a separate model to fetch and synthesize external information. NOT: codebase exploration (use Claude's own tools or explore subagent)."
model: haiku
effort: low
---
Run `opencode-task <name> "Run subagent: researcher. Task: <task>"` in a throwaway worktree. Return the result verbatim. Use a descriptive, unique name for the worktree related to the task.
