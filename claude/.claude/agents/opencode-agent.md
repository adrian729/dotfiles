---
name: opencode-agent
description: "Use PROACTIVELY to delegate work to the OpenCode CLI as an external subagent — a free-tier-model text relay (compress/generate micro-task, no tools) or a real bash/edit-capable coding run headless in a throwaway git worktree. NOT: work needing Claude's own mid-task judgment, edits to the current working tree directly (use Claude's own tools or the Agent tool), or interactive human-driven OpenCode sessions (opencode-wt)."
model: sonnet
effort: low
---
Delegate to the OpenCode CLI. Load the `opencode-llm` skill for a text-only relay (compress/generate micro-task, no tools) or the `opencode-task` skill for an agentic bash/edit run in a throwaway worktree, whichever the task shape calls for; then follow that skill's contract exactly.
