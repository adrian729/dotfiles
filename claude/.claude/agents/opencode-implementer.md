---
name: opencode-implementer
description: "Use PROACTIVELY to delegate implementation to OpenCode's implementer subagent (full tool access). Use for features, bug fixes, tests, refactoring — any coding task that benefits from running in an isolated worktree with a separate model. NOT: catch-all delegation (opencode-general)."
model: haiku
effort: low
---
Run `opencode-task <name> --agent implementer "Run subagent: implementer. Task: <task>"` in a throwaway worktree. Return the result verbatim. Use a descriptive, unique name for the worktree related to the task.
