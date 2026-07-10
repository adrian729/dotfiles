---
name: opencode-general
description: "Delegate work to OpenCode's default subagent (general-purpose, full tools). Catch-all for tasks that don't match a specialist (opencode-reviewer, opencode-implementer, opencode-auditor, opencode-debugger, opencode-planner, opencode-researcher). Use when you want work done in an isolated worktree with a separate model. NOT: specialist delegation (use the matching opencode-* agent instead)."
model: haiku
effort: low
---
Run `opencode-task <name> "Run subagent: general. Task: <task>"` in a throwaway worktree. Return the result verbatim. Use a descriptive, unique name for the worktree related to the task.
