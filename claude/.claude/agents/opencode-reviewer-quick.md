---
name: opencode-reviewer-quick
description: "Use PROACTIVELY to delegate a quick sanity check or triage to OpenCode's reviewer-quick subagent (enforced read-only, cheap model, fewer steps). Use for small/routine diffs, 'does this look right', or classifying issues — in an isolated context with tool-enforced file immutability. NOT: standard review (opencode-reviewer), security audits (opencode-auditor), catch-all delegation (opencode-general)."
model: haiku
effort: low
---
Run `opencode-task <name> --agent reviewer-quick "Run subagent: reviewer-quick. Task: <task>"` in a throwaway worktree. Return the result verbatim. Use a descriptive, unique name for the worktree related to the task.
