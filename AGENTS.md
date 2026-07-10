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

## Per-package file layout

```
claude/
  .claude/
    CLAUDE.md          @imports agents/.agents/AGENTS.md + fable addendum
    settings.json      (copied by install.sh, not symlinked)
    settings.local.json (per-machine overrides, .stow-local-ignored)
    statusline.sh
    agents/            38 agent defs — YAML-frontmatter .md
    hooks/             agent-eval, agent-guard, agent-skill-nudge, skill-eval
    skills/            12 SKILL.md dirs
    tmp/
  .local/scripts/      claude-wt, git-wt, llm, llm-probe, open-wt, opencode-llm, opencode-task
  .stow-local-ignore
  install.sh

opencode/
  .config/opencode/
    opencode.json      (copied by install.sh, not symlinked)
    AGENTS.md -> ../../../agents/.agents/AGENTS.md (symlink)
    tui.json
  .local/scripts/      opencode-git-wt, opencode-open-wt, opencode-wt
  .stow-local-ignore
  install.sh

agents/
  .agents/
    AGENTS.md          shared behavior rules (deployed to ~/.agents/)
    ARCHITECTURE.md    design rationale (.stow-local-ignored — not deployed)
  .stow-local-ignore

nvim/
  .config/nvim/
    init.lua
    lazy-lock.json
    lua/config/        options.lua, keymaps.lua, autocmds.lua, lazy.lua
    lua/plugins/       autocomplete, catppuccin, codecompanion, core, fzf, git, lsp, markdown, rename, telescope, treesitter
    .claude/settings.local.json
    lorem-ipsum.txt

tmux/
  .config/tmux/
    tmux.conf          TPM-based, catppuccin theme, plugins managed at runtime
  .local/scripts/      ready-tmux, tmux-sessionizer
  .gitignore           excludes plugins/* (installed by TPM)

zsh/
  .zshenv              sets ZDOTDIR -> ~/.config/zsh
  .profile
  .config/zsh/
    .zshrc             oh-my-zsh + homebrew/llvm/nvm/autojump/fzf/ollama
    aliases.zsh        ll, la, l, gitstashpull, nc_tcp_write, nc_udp_listen
    plugins/
      .keep
      zsh-autosuggestions/   (vendored, full git repo)
      zsh-syntax-highlighting/ (vendored, full git repo)
  .gitignore

ghostty/
  .config/ghostty/
    config             2-line: theme reference
    themes/catppuccin-mocha.conf

kitty/
  .config/kitty/
    kitty.conf         Fira Code 14px, includes theme.conf
    theme.conf         Catppuccin-Macchiato + bg images
    *.png              4 background images

ollama/
  .config/ollama/
    ollama.env.template (ollama.env gitignored — secrets)
  .gitignore
  install.sh

clangd/
  .config/clangd/
    config.yaml        -std=c++23 fallback
```

## install.sh flow (repo root)

1. Verifies `stow` binary exists
2. Stows all 10 packages (or prompts per-package unless `-y`)
3. Runs per-package `install.sh` if present:
   - **claude/install.sh**: copies `settings.json` (not symlink → tool can modify freely), sets `editorMode: "vim"` in `~/.claude.json`, probes local LLM
   - **opencode/install.sh**: copies `opencode.json` (not symlink)
   - **ollama/install.sh**: checks `ollama.env` exists, prints reminder if not

Key design: `settings.json`/`opencode.json` are **copied** so tools can modify freely without dirtying the repo. Re-running install.sh resets from repo version.

## `.stow-local-ignore` exclusions

| Package | Excluded | Reason |
|---|---|---|
| `claude/` | guides, install.sh, settings.json, settings.local.json | docs, per-machine, or must be copied |
| `opencode/` | guides, install.sh, opencode.json | docs, or must be copied |
| `agents/` | ARCHITECTURE.md | design doc, not deployed |

## Task→Package map

| Task | Which package to touch |
|---|---|
| Change shell prompt/alias/env | `zsh/` (aliases.zsh, .zshrc, .zshenv) |
| Change terminal (font, theme, bg) | `ghostty/` or `kitty/` |
| Change tmux keybind/layout | `tmux/` (tmux.conf) |
| Change Neovim plugin/setting | `nvim/` (lua/plugins/*.lua or lua/config/*.lua) |
| Add/update AI agent def | `claude/.claude/agents/` (+ mirror in opencode if OpenCode needs it) |
| Add/update AI skill | `claude/.claude/skills/<name>/SKILL.md` |
| Add/update AI hook | `claude/.claude/hooks/` |
| Change tool permissions | `claude/.claude/settings.json` + mirror in `opencode/.config/opencode/opencode.json` |
| Change shared agent rules (both tools) | `agents/.agents/AGENTS.md` |
| Bootstrap a new machine | `install.sh` (repo root) |
| Add new stow package | Create `<name>/` dir, add to `install.sh` stow list |

## Non-package repo items

| Path | Purpose |
|---|---|
| `.claude/worktrees/` | Claude Code worktrees (not stowed) |
| `.opencode/worktrees/` | OpenCode worktrees (not stowed) |
| `ai-agent-patterns/` | Agent pattern design docs (not stowed) |
| `.gitignore` | Excludes `.gitconfig` |
| `install.sh` | Bootstrap entry point (repo root) |
| `.ready-tmux` | Script: opens nvim in tmux split layout |

## Non-stowed config files (per-machine)

- `~/.claude.json` — Claude Code user-level settings (editorMode set by install.sh)
- `~/.gitconfig` — git config (excluded from repo via .gitignore, created manually)
- `~/.config/ollama/ollama.env` — Ollama API key (gitignored, template provided)
- `~/.config/opencode/opencode.json` — copied from repo (tool may modify)
- `~/.claude/settings.json` — copied from repo (tool may modify)
