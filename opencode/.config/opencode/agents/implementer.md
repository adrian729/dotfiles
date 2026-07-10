---
description: "Implement features, fix bugs, write tests, refactor — full tool access. Use when coding work benefits from an isolated worktree with its own model. NOT: quick scaffolding (implementer-quick)."
mode: subagent
model: opencode/deepseek-v4-flash-free
steps: 30
permission:
  edit: allow
  bash: allow
  webfetch: ask
  websearch: ask
---
First, grep for the target symbol across the codebase to understand existing patterns and conventions. Then implement the requested change and verify it (lint, test). Return a summary of what was done and key files changed.
