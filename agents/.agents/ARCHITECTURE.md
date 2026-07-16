# Unified config architecture — rationale

Living rationale for how this dotfiles repo shares config across Claude Code and OpenCode (and, later, a third tool such as Cursor). Not deployed by stow (see `.stow-local-ignore`) — it's the *why* behind the layout, for whoever adds tool #3.

## 1. Per-layer unifiability verdict

- **Memory / instructions — unified.** The genuinely tool-agnostic behavior rules live once in `agents/.agents/AGENTS.md` (stows to `~/.agents/AGENTS.md`). Each tool's own expected memory file points at it: Claude Code's `claude/.claude/CLAUDE.md` uses a relative `@import` (`@../../agents/.agents/AGENTS.md`) plus a Claude-only addendum; OpenCode's `~/.config/opencode/AGENTS.md` is a git-tracked relative symlink to the same file. Cursor (later) reads project-root `AGENTS.md` natively.
- **Skills — already unified, no adapter.** OpenCode natively discovers `.claude/skills/*/SKILL.md` (same open `name`+`description` frontmatter). Cursor reads `.cursor/skills/` — same file format, different path, so a per-project symlink works unmodified.
- **Agents — unified for Claude ↔ Cursor only.** Cursor natively reads `.claude/agents/*.md` (ignores the extra `effort` field harmlessly). OpenCode does **not** read `.claude/agents/` at all — its subagents live only under `opencode/.config/opencode/agents/` or the `agent` key in `opencode.json`, a structurally different schema (`mode`, `temperature`, `permission` vs `model`, `effort`). See accepted gap (a).
- **Hooks — not unifiable.** Claude Code's `settings.json` hooks have no cross-tool equivalent worth translating. OpenCode's plugin system *can* block a tool call (`tool.execute.before` throwing) — a real `PreToolUse`-deny analogue — but has **no** per-turn context-injection hook (nothing like `UserPromptSubmit` + `additionalContext`). Of this repo's 4 hooks: `skill-eval.sh` and `agent-skill-nudge.sh` are moot in OpenCode by design (its native `skill` tool is always visible); `agent-eval.sh` and `agent-guard.sh` depend on the OpenCode-subagent-roster gap (a), so they ride along with it. Nothing to build now.
- **Permissions — mirrored by hand, not shared.** OpenCode's permission schema is genuinely three-state (`allow`/`ask`/`deny`) with arg-pattern matching, rich enough to express Claude's rules — but differently shaped (top-level tool categories + bash sub-command patterns vs Claude's `Tool(pattern)` list). Not auto-translated; the standing directive in the repo-root `AGENTS.md` says to mirror changes by hand into `opencode.json`'s `permission` block.
- **LSP — hand-maintained separately.** Claude's `enabledPlugins` references its plugin marketplace (`pyright-lsp`, `rust-analyzer-lsp`, `lua-lsp`, `clangd-lsp`); OpenCode's `lsp` key directly defines server commands (`lua-ls`, `marksman`). Different server sets even today, low churn — a translator isn't worth it.
- **Effort / model dials, statusline — Claude-only.** No analog elsewhere; not shared.

## 2. Accepted gaps, with reasoning

- **(a) OpenCode has no general-purpose tiered subagent roster.** `opencode.json`'s `agent` key defines only `relay` and `task` — the two narrow delegation targets `opencode-llm`/`opencode-task` call into — nothing like Claude's full tiered roster (implementer/planner/reviewer/…, each with quick/base/deep tiers). Decided: leave this documented rather than hand-author a parallel OpenCode-native set now. Revisit if standalone OpenCode use grows enough to want it. Hooks `agent-eval.sh`/`agent-guard.sh` ride along with this gap.
- **(b) Cursor has no global/personal memory-file concept** — it's project-scoped by design. Inherent tool limit, not a gap in this architecture. In other projects, add a per-project `AGENTS.md` (optionally symlinked to `~/.agents/AGENTS.md` if no project-specific addenda are needed) only when actually working there in Cursor.
- **(c) Hooks / permissions / effort / statusline have no cross-tool equivalent** — checked, not assumed (see §1). Nothing to build until gap (a) is revisited.

## 3. Why relative imports, not `~`-prefixed

Claude Code's `@import` uses a **relative** path (`@../../agents/.agents/AGENTS.md`), resolved from `claude/.claude/`'s real repo location, not the stowed `~/.agents/...` path. This is deliberate: Claude Code's docs document relative imports as the reliable primary mechanism, while `@~/...` tilde-prefixed imports hit a confirmed, currently-unfixed bug (GitHub issue #8765: silently ignored, closed by Anthropic as "not planned"). Do **not** "simplify" the import back to a tilde path — it will silently stop loading.

## 4. The symlink-resolution mechanic — now verified

Claude's global-memory pointer (`claude/.claude/CLAUDE.md`, deployed as the `~/.claude/CLAUDE.md` stow symlink) is read from *any* project's cwd. Claude Code's `@import` resolver computes the relative path against the symlink's **real target directory**, not the symlink path itself — confirmed directly (2026-07-15/16): the deployed `CLAUDE.md` had drifted to `@../.agents/AGENTS.md` (one level short of this doc's §3 spec), which resolves to a nonexistent file under the real directory but *would* have resolved successfully under the symlink path (`~/.agents/AGENTS.md`, itself stow-deployed). The import sat unexpanded — no injected content block for the shared-rules file appeared in-session, confirming real-path resolution — until corrected back to `@../../agents/.agents/AGENTS.md`. The project-level import (`@../AGENTS.md`, both files plain, never via a symlink) and OpenCode's OS-level symlink have zero exposure to this either way.

## 5. Naming note

`agents/` (this stow package, stows to `~/.agents/`, holds the shared `AGENTS.md`) and `claude/.claude/agents/` (Claude Code's own subagent definitions) are **unrelated** directories that merely share the word "agents". Don't conflate them when editing.
