---
name: opencode-implementer-quick
description: "Use PROACTIVELY to delegate quick scaffolding or boilerplate to OpenCode's implementer-quick subagent (full tool access, cheap model, fewer steps). Use for stubs, skeletons, small self-contained edits — mechanical coding tasks that benefit from running in an isolated worktree with a separate model. NOT: real implementation (opencode-implementer), catch-all delegation (opencode-general)."
model: haiku
effort: low
---
Run `opencode-task <name> --agent implementer-quick "Run subagent: implementer-quick. Task: <task>"` in a throwaway worktree. Return the result verbatim. Use a descriptive, unique name for the worktree related to the task.
