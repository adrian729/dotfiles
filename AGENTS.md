# dotfiles repo structure

This is a [GNU Stow](https://www.gnu.org/software/stow/) dotfiles farm. Each top-level directory is a stow package deployed to `~`:

| Package | Stows to | What's in it |
|---|---|---|
| `claude/` | `~/.claude/` | Claude Code config: agents, skills, hooks, scripts |
| `opencode/` | `~/.config/opencode/` | OpenCode config |
| `agents/` | `~/.agents/` | Shared, tool-agnostic behavior rules (`AGENTS.md`) |
| `nvim/` | `~/.config/nvim/` | Neovim config |
| `tmux/` | `~/.config/tmux/` | tmux config |
| `zsh/` | `~/.config/zsh/` | Zsh config |
| `ghostty/` | `~/.config/ghostty/` | Ghostty terminal config |
| `kitty/` | `~/.config/kitty/` | Kitty terminal config |
| `ollama/` | `~/.config/ollama/` | Ollama config |
| `clangd/` | `~/.config/clangd/` | clangd config |

Shared, tool-agnostic behavior rules live in `~/.agents/AGENTS.md` (the `agents/` package). Claude Code pulls them into `claude/.claude/CLAUDE.md` via a relative `@import`; OpenCode's `~/.config/opencode/AGENTS.md` is a symlink to the same file.

## Key paths for Claude Code work

- **`claude/.claude/skills/`** — SKILL.md files. This is the canonical skills directory. Skills go here, not under `.claude/skills/` at repo root. OpenCode natively discovers these too.
- **`claude/.claude/agents/`** — Claude Code agent definitions (implementer, planner, researcher, writer, debugger, reviewer, auditor, analyzer, summarizer, operator, cleaner, explorer, effort-*, most with quick/base/deep tiers). OpenCode does **not** read `.claude/agents/`; its subagents are defined under the `agent` key in `opencode/.config/opencode/opencode.json`.
- **`claude/.claude/hooks/`** — guard and eval hooks.
- **`claude/.local/scripts/`** — utility scripts for claude worktree management.
- **`ai-agent-patterns/`** — reference docs for agent patterns (best-of-n plan, pattern catalog). Not a config directory — design docs only.

## Rules

- claude operational config (agents, skills, hooks, scripts, settings) goes under `claude/.claude/`. Root `.claude/` holds project CLAUDE.md and `worktrees/` only.
- When creating a new skill, the path is `claude/.claude/skills/<name>/SKILL.md`.
- `.stow-local-ignore` files in `claude/`, `opencode/`, and `agents/` exclude files from stow symlinking.
- `install.sh` at repo root is the bootstrap installer.
- Worktrees for claude go in `.claude/worktrees/` or `.opencode/worktrees/`.
- When `claude/.claude/settings.json`'s `permissions` block changes, mirror the same rule into `opencode/.config/opencode/opencode.json`'s `permission` block, translated into OpenCode's own schema (bash sub-command patterns, three-state `allow`/`ask`/`deny`). Keep OpenCode's permissive `"*": "allow"` bash default as the baseline unless a change explicitly says otherwise.
