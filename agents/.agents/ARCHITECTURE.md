# Shared configuration layout

This document explains the repository layout; Stow does not deploy it.

- Shared rules live in `agents/.agents/AGENTS.md`. Claude imports them from its global `CLAUDE.md`; OpenCode links to them from its global `AGENTS.md`. Codex deliberately has no global rules link.
- Shared skills belong in `agents/.agents/skills/`. Codex discovers them there; Claude can link to them from its skills directory. Existing Claude and delegation skills remain under `claude/.claude/skills/`, which OpenCode also discovers.
- Agent definitions are tool-specific: Claude has its role/tier agents, effort carriers, and OpenCode delegation wrappers; OpenCode has eight agent files plus `relay` and `task` in its JSON configuration. Do not assume one tool reads the other's agent files.
- Native discovery selects skills and agents. Claude has no active orchestration hooks; the old hook paths remain as no-op stubs because previously copied settings may still call them. Explicitly requested workflow skills retain their process instructions.
- Permissions use different schemas and are maintained separately. Follow the root `AGENTS.md` rule when mirroring permission changes. OpenCode's configured model lists and installer keep delegation on explicit free models unless paid usage is explicitly requested.
- LSP integrations, model/effort defaults, and status displays remain tool-specific.

## Imports and deployment

Claude's global `CLAUDE.md` imports `@../../agents/.agents/AGENTS.md`. This resolves from its real repository location, `claude/.claude/`, rather than the deployed symlink's directory. That behavior was observed in this setup in July 2026; preserve the relative path unless rechecking the deployed import. The project-level `.claude/CLAUDE.md` separately imports `@../AGENTS.md`.

Stow uses `--no-folding` so target directories remain real directories. Mutable Claude, OpenCode, and Codex settings are copied by their installers, allowing local tool state without writes into Git. Re-running an installer replaces those copied settings with the repository baseline; edits to stowed agent and skill files are visible through their symlinks.

The `agents/` package owns shared rules and skills. The similarly named `claude/.claude/agents/` directory owns Claude subagent definitions.
