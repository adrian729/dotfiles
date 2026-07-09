# Global opencode rules — use the Claude Code setup

This project's canonical config lives under `~/.claude/`.
opencode reads it via built-in Claude Code compatibility, but
this AGENTS.md makes the relationship explicit so the model
always knows where to find things.

- **Project rules**: `~/.claude/CLAUDE.md`
- **Skills**: `~/.claude/skills/` — e.g. audit-loop, local-llm, limit-relay, etc.
- **Agents**: `~/.claude/agents/` — e.g. planner, implementer, reviewer, etc.
- **Global settings**: `~/.claude/settings.json`
