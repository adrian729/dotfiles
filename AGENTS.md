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
| `lf/` | `~/.config/lf/` | lf file manager config |

Shared, tool-agnostic behavior rules live in `~/.agents/AGENTS.md` (the `agents/` package). Claude Code pulls them into `claude/.claude/CLAUDE.md` via a relative `@import`; OpenCode's `~/.config/opencode/AGENTS.md` is a symlink to the same file.

## Key paths for Claude Code work

- **`claude/.claude/skills/`** — SKILL.md files. This is the canonical skills directory. Skills go here, not under `.claude/skills/` at repo root. OpenCode natively discovers these too.
- **`claude/.claude/agents/`** — Claude Code agent definitions (implementer, planner, researcher, writer, debugger, reviewer, auditor, analyzer, summarizer, operator, cleaner, explorer, effort-*, opencode-* delegation wrappers, most with quick/base/deep tiers). OpenCode does **not** read `.claude/agents/`; its own subagents are separate `.md` files under `opencode/.config/opencode/agents/` (the `agent` key in `opencode.json` itself only holds `relay`/`task`).
- **`claude/.claude/hooks/`** — guard and eval hooks.
- **`claude/.local/scripts/`** — utility scripts for claude worktree management.

## Rules

- claude operational config (agents, skills, hooks, scripts, settings) goes under `claude/.claude/`. Root `.claude/` holds project CLAUDE.md and `worktrees/` only.
- When creating a new skill, the path is `claude/.claude/skills/<name>/SKILL.md`.
- Every package has a `.stow-local-ignore` excluding at least its own `install.sh` from stow symlinking — see the exclusions table below for package-specific extras.
- `install.sh` at repo root is the bootstrap installer.
- Worktrees for claude go in `.claude/worktrees/` or `.opencode/worktrees/`.
- When `claude/.claude/settings.json`'s `permissions` block changes, mirror the same rule into `opencode/.config/opencode/opencode.json`'s `permission` block, translated into OpenCode's own schema (bash sub-command patterns, three-state `allow`/`ask`/`deny`). Keep OpenCode's permissive `"*": "allow"` bash default as the baseline unless a change explicitly says otherwise. Exception, deliberately not mirrored: Claude's `allow` list explicitly allowlists `Bash(opencode-task*)`/`Bash(opencode-llm*)` so Claude can shell out to OpenCode; OpenCode has no equivalent entry, since it shouldn't shell out to itself (enforced today only by the `opencode-task`/`opencode-llm` skills' own anti-triggers, not a permission rule).

## Per-package file layout

```
claude/
  .claude/
    CLAUDE.md          @imports agents/.agents/AGENTS.md + fable addendum
    settings.json      (copied by install.sh, not symlinked)
    settings.local.json (per-machine overrides, .stow-local-ignored)
    claude.env.template (claude.env is gitignored — secrets, sourced by zsh's nested .zshenv)
    statusline.sh
    agents/            44 agent defs — YAML-frontmatter .md (incl. 9 opencode-* delegation wrappers)
    hooks/             agent-eval, agent-guard, agent-skill-nudge, skill-eval
    skills/            12 SKILL.md dirs
    tmp/
  .local/scripts/      claude-wt, git-wt, llm, llm-models-probe, llm-probe,
                       open-wt, opencode-llm, opencode-task
  .stow-local-ignore
  install.sh

opencode/
  .config/opencode/
    MODELS.md          machine-readable model catalog
    opencode.json      (copied by install.sh, not symlinked)
    AGENTS.md -> ../../../agents/.agents/AGENTS.md (symlink)
    tui.json
    agents/            8 agent .md files (auditor, debugger, implementer,
                       implementer-quick, planner, researcher, reviewer,
                       reviewer-quick)
  .local/
    config/            opencode-models.json (unified model config)
    scripts/           opencode-git-wt, opencode-open-wt, opencode-wt,
                       opencode-llm-probe, opencode-agent-models-probe,
                       opencode-models
  .stow-local-ignore
  install.sh

agents/
  .agents/
    AGENTS.md          shared behavior rules (deployed to ~/.agents/)
    ARCHITECTURE.md    design rationale (.stow-local-ignored — not deployed)
  .stow-local-ignore
  install.sh           no-op placeholder (nothing to bootstrap for this package)

nvim/
  .config/nvim/
    init.lua
    lazy-lock.json
    lua/config/        options.lua, keymaps.lua, autocmds.lua, lazy.lua
    lua/plugins/       autocomplete, catppuccin, codecompanion, core, fzf, git, lsp, markdown, rename, telescope, treesitter
    .claude/settings.local.json
    lorem-ipsum.txt
  .stow-local-ignore
  install.sh

tmux/
  .config/tmux/
    tmux.conf          TPM-based, catppuccin theme, plugins managed at runtime
    default_KBs_lists.txt (static `tmux list-keys` reference dump, unreferenced)
    .gitignore         excludes plugins/* (installed by TPM)
  .local/scripts/      ready-tmux, tmux-sessionizer, tmux-ollama-status,
                       tmux-usage-status
  .stow-local-ignore
  install.sh

zsh/
  .zshenv              sets ZDOTDIR -> ~/.config/zsh, sources $ZDOTDIR/.zshenv
  .config/zsh/
    .zshenv            EDITOR/VISUAL/MANPAGER/GPG_TTY/STARSHIP_CONFIG, cargo/
                       ollama.env/claude.env sourcing, PATH additions
    .zshrc             starship + zoxide (no oh-my-zsh); sources fzf.zsh,
                       aliases.zsh, bindings.zsh, plugins.zsh, prompt.zsh
    aliases.zsh        ls/ll/la/tree (eza), cat->bat, grep->rg, lf wrapper,
                       glog/gadog, dotfiles bare-repo alias, nc_tcp_write,
                       nc_udp_listen
    bindings.zsh       zsh-vi-mode cursor/keybinding overrides
    fzf.zsh            fzf defaults + Ctrl-F file picker
    plugins.zsh        git-clones + sources 4 plugins below on first run
    prompt.zsh         starship init
    starship.toml
    plugins/           auto-cloned, gitignored (not vendored):
                       fast-syntax-highlighting/, zsh-autosuggestions/,
                       zsh-history-substring-search/, zsh-vi-mode/
  .gitignore
  .stow-local-ignore
  install.sh

ghostty/
  .config/ghostty/
    config             2-line: theme reference
    themes/catppuccin-mocha.conf
  .stow-local-ignore
  install.sh

kitty/
  .config/kitty/
    kitty.conf         Fira Code 14px, includes theme.conf
    theme.conf         Catppuccin-Macchiato + bg images
    *.png              4 background images
  .stow-local-ignore
  install.sh

ollama/
  .config/ollama/
    ollama.env.template (ollama.env gitignored — secrets)
  .local/scripts/      ollama-ctl
  .gitignore
  .stow-local-ignore
  install.sh

clangd/
  .config/clangd/
    config.yaml        -std=c++23 fallback
  .stow-local-ignore
  install.sh

lf/
  .config/lf/
    lfrc               quit-without-cd on Q/Esc
    icons
  .stow-local-ignore
  install.sh
```

## install.sh flow (repo root)

1. Bootstraps Homebrew if missing, then verifies/installs `stow`
2. Stows all 11 packages from its `directories` array (or prompts per-package unless answering "y" to "stow all")
3. Runs each package's own `install.sh` if present — all 11 packages have one now, mostly an idempotent `brew install <tool>` guard (`command -v` check; `agents/install.sh` is a no-op placeholder). Notable exceptions:
   - **claude/install.sh**: also brew-installs the `claude` CLI itself, copies `settings.json` (not symlink → tool can modify freely), sets `editorMode: "vim"` in `~/.claude.json`, probes local LLM
   - **opencode/install.sh**: copies `opencode.json` (not symlink), probes free-tier model availability
   - **ollama/install.sh**: checks `ollama.env` exists, prints reminder if not

Key design: `settings.json`/`opencode.json` are **copied** so tools can modify freely without dirtying the repo. Re-running install.sh resets from repo version.

## `.stow-local-ignore` exclusions

Every package now has a `.stow-local-ignore` excluding at least its own `^/install\.sh`. Package-specific extras beyond that:

| Package | Extra exclusions | Reason |
|---|---|---|
| `claude/` | guides, `settings.json`, `settings.local.json`, `claude.env` | docs, per-machine, or must be copied/gitignored |
| `opencode/` | guides, `opencode.json` | docs, or must be copied |
| `agents/` | `ARCHITECTURE.md` | design doc, not deployed |
| `ollama/` | `.gitignore`, `ollama.env` | not meant to be symlinked out |
| `zsh/` | `.gitignore` | not meant to be symlinked out |

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
| `.gitignore` | Excludes `.gitconfig` and `claude/.claude/claude.env` |
| `install.sh` | Bootstrap entry point (repo root) |
| `.ready-tmux` | Script: opens nvim in tmux split layout |

## Non-stowed config files (per-machine)

- `~/.claude.json` — Claude Code user-level settings (editorMode set by install.sh)
- `~/.gitconfig` — git config (excluded from repo via .gitignore, created manually)
- `~/.config/ollama/ollama.env` — Ollama API key (gitignored, template provided)
- `~/.config/opencode/opencode.json` — copied from repo (tool may modify)
- `~/.claude/settings.json` — copied from repo (tool may modify)
