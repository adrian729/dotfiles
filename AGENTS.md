# dotfiles repo structure

This is a [GNU Stow](https://www.gnu.org/software/stow/) dotfiles farm. Each top-level directory is a stow package deployed to `~`:

| Package         | Stows to                  | What's in it                                       |
| --------------- | ------------------------- | -------------------------------------------------- |
| `claude/`       | `~/.claude/`              | Claude Code config: agents, skills, hooks, scripts |
| `opencode/`     | `~/.config/opencode/`     | OpenCode config                                    |
| `agents/`       | `~/.agents/`              | Shared, tool-agnostic behavior rules (`AGENTS.md`) |
| `nvim/`         | `~/.config/nvim/`         | Neovim config                                      |
| `tmux/`         | `~/.config/tmux/`         | tmux config                                        |
| `zsh/`          | `~/.config/zsh/`          | Zsh config                                         |
| `ghostty/`      | `~/.config/ghostty/`      | Ghostty terminal config                            |
| `kitty/`        | `~/.config/kitty/`        | Kitty terminal config                              |
| `ollama/`       | `~/.config/ollama/`       | Ollama config                                      |
| `clangd/`       | `~/.config/clangd/`       | clangd config                                      |
| `lf/`           | `~/.config/lf/`           | lf file manager config                             |
| `bettercmdtab/` | `~/.config/bettercmdtab/` | BetterCmdTab config (copied, not symlinked)        |

Shared, tool-agnostic behavior rules live in `~/.agents/AGENTS.md` (the `agents/` package). Claude Code pulls them into `claude/.claude/CLAUDE.md` via a relative `@import`; OpenCode's `~/.config/opencode/AGENTS.md` is a symlink to the same file.

## Key paths for Claude Code work

- **`claude/.claude/skills/`** — SKILL.md files. This is the canonical skills directory. Skills go here, not under `.claude/skills/` at repo root. OpenCode natively discovers these too.
- **`claude/.claude/agents/`** — Claude Code agent definitions (implementer, planner, researcher, writer, debugger, reviewer, auditor, analyzer, summarizer, operator, cleaner, explorer, effort-_, opencode-_ delegation wrappers, most with quick/base/deep tiers). OpenCode does **not** read `.claude/agents/`; its own subagents are separate `.md` files under `opencode/.config/opencode/agents/` (the `agent` key in `opencode.json` itself only holds `relay`/`task`).
- **`claude/.claude/hooks/`** — guard and eval hooks.
- **`claude/.local/scripts/`** — utility scripts for claude worktree management.

## Rules

- claude operational config (agents, skills, hooks, scripts, settings) goes under `claude/.claude/`. Root `.claude/` holds project CLAUDE.md only.
- When creating a new skill, the path is `claude/.claude/skills/<name>/SKILL.md`.
- Every package has a `.stow-local-ignore` excluding at least its own `install.sh` from stow symlinking — see the exclusions table below for package-specific extras.
- `install.sh` at repo root is the bootstrap installer.
- Worktrees for claude and opencode share a single root: `.worktrees/<name>/` — either tool can attach to the same worktree/branch/color under one name. Each tool still tracks its own AI conversation state (Claude via `~/.claude/projects/`, OpenCode via its own session DB + the `wt.<name>.session` git-config key) — sharing a name shares the checkout, not a single AI session.
- OpenCode's agent-level `permission.bash` block fully replaces (does not merge with) `opencode.json`'s top-level one, so the 7-pair bash deny list (`git push`/`npm publish`/`gh release`/`docker push`/`terraform apply`/`kubectl apply`/`cargo publish`) is duplicated verbatim across `opencode.json` and `opencode/.config/opencode/agents/{debugger,implementer,implementer-quick}.md`. Since `opencode.json` is plain JSON (no comments to flag this), if you add to the deny list in one place, add it in all four.
- When `claude/.claude/settings.json`'s `permissions` block changes, mirror the same rule into `opencode/.config/opencode/opencode.json`'s `permission` block, translated into OpenCode's own schema (bash sub-command patterns, three-state `allow`/`ask`/`deny`). Keep OpenCode's permissive `"*": "allow"` bash default as the baseline unless a change explicitly says otherwise. Exception, deliberately not mirrored: Claude's `allow` list explicitly allowlists `Bash(opencode-task*)`/`Bash(opencode-llm*)` so Claude can shell out to OpenCode; OpenCode has no equivalent entry, since it shouldn't shell out to itself (enforced today only by the `opencode-task`/`opencode-llm` skills' own anti-triggers, not a permission rule). Second exception, also deliberate: `npm publish`/`gh release`/`docker push`/`terraform apply`/`kubectl apply`/`cargo publish` are `ask` in `claude/.claude/settings.json` but `deny` in `opencode.json` — Claude's `ask` works because a human is present to answer the prompt, but OpenCode's unattended `--auto` runs have nobody to ask, so the equivalent safety there is a hard `deny`, not a translated `ask`. Don't "fix" this by loosening opencode.json's `deny` back to `ask`.
- Every OpenCode agent that needs a pinned model must have an entry in `opencode/.local/config/opencode-models.json`'s `agents` map: `opencode-agent-models-probe` only iterates that map's keys, and `opencode/install.sh` jq-merges the resulting `{agent: {<name>: {model: …}}}` into the copied `~/.config/opencode/opencode.json`. An agent missing from the map gets no `model` and falls through to OpenCode's ambient default, which may be a paid model. All 10 agents are covered. `relay`'s list duplicates the top-level `relay` key, which is a different mechanism (`opencode-llm` reads that one to build its `-m` fallback walk) — keep the two in sync, or drop the `agents` entry if the duplication ever drifts. Paid (`opencode-go/*`) entries inside a list are inert ranking hints: the probe skips any candidate that isn't also in `free_models`, so a list can express preference order without ever selecting a paid model.
- The manual-only skill list is duplicated: `skillOverrides` in `claude/.claude/settings.json` (which sets them `name-only` in the harness listing) and `MANUAL_ONLY` in `claude/.claude/hooks/lib/skill-names.sh` (which keeps the nudge hooks from suggesting them). Both currently hold the same four — `audit-loop`, `autonomous-process`, `best-of-n`, `evaluator-optimizer`. Adding or removing a manual-only skill means editing both; they serve different mechanisms and neither derives from the other.

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
                       lib/skill-names.sh (shared skill listing, sourced by two of them)
    skills/            12 SKILL.md dirs
    tmp/
   .local/
    config/            local-llm-models.json (static ollama model catalog)
    scripts/           claude-wt, git-wt, llm, llm-models-probe, llm-probe,
                       open-wt, opencode-llm, opencode-task
  .stow-local-ignore
  install.sh
  pre_stow.sh          clears standalone script copies out of ~/.local/scripts

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
  pre_stow.sh          clears standalone script copies out of ~/.local/scripts

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
    lua/plugins/       autocomplete, catppuccin, codecompanion, colorizer, core, fzf, git, harpoon, lsp, markdown, rename, telescope, treesitter
    .claude/settings.local.json
  _nvim_ai/            stubs pointing at ~/projects/ducktape.nvim's own docs (the AI layer that
                       used to live in lua/ai/ is now that standalone plugin, not part of this repo)
  .stow-local-ignore
  install.sh

`lua/plugins/codecompanion.lua` depends on `~/projects/ducktape.nvim` existing locally: `lua/config/lazy.lua`'s `dev = { path = "~/projects", patterns = { "adrian729" }, fallback = true }` makes lazy.nvim consume that local checkout when present, falling back to a normal GitHub clone (`adrian729/ducktape.nvim`, public) on a machine without it. `fallback = true` is required — lazy.nvim's `dev.patterns` matching otherwise forces the local path unconditionally even when it's absent, breaking any machine but this one.

tmux/
  .config/tmux/
    tmux.conf          TPM-based, catppuccin theme, plugins managed at runtime
    default_KBs_lists.txt (static `tmux list-keys` reference dump, unreferenced)
    .gitignore         excludes plugins/* (installed by TPM)
   .local/scripts/      ready-tmux, tmux-sessionizer, tmux-session-tracker,
                        tmux-keymaps, tmux-clipboard, tmux-ollama-status,
                        tmux-usage-status, wt-sessionizer
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
  .config/eza/
    theme.yml          Catppuccin Mocha (mauve accent), vendored from
                       catppuccin/eza
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

bettercmdtab/
  .config/bettercmdtab/
    config.json        (copied by install.sh, not symlinked — live two-way sync)
  .stow-local-ignore
  install.sh
```

## install.sh flow (repo root)

1. Bootstraps Homebrew if missing, then verifies/installs `stow`
2. Stows all 12 packages from its `directories` array (or prompts per-package unless answering "y" to "stow all"), via a `stow_pkg` helper that runs the package's `pre_stow.sh` first if it has one. `pre_stow.sh` is for work that must happen while the target files are still unstowed — the two that exist (`claude/`, `opencode/`) delete the plain script copies `standalone_quick_setup.sh` leaves in `~/.local/scripts`, which stow would otherwise refuse to overwrite. Keep this hook generic in root `install.sh`; package-specific logic belongs in the package's own `pre_stow.sh`. A failing `pre_stow.sh` warns and stows anyway.
3. Runs each package's own `install.sh` if present — all 12 packages have one now, mostly an idempotent `brew install <tool>` guard (`command -v` check; `agents/install.sh` is a no-op placeholder). Notable exceptions:
   - **claude/install.sh**: also installs the `claude` CLI itself (brew cask on macOS, `claude.ai/install.sh` on Linux — Linuxbrew has no cask support), copies `settings.json` (not symlink → tool can modify freely), sets `editorMode: "vim"` in `~/.claude.json`, probes local LLM
   - **opencode/install.sh**: copies `opencode.json` (not symlink), probes free-tier model availability
   - **bettercmdtab/install.sh**: brew-installs `bettercmdtab`, copies `config.json` (not symlink → app writes back live), sets trigger hotkeys via `defaults write` (⌥Tab/⌥` to leave ⌘Tab/⌘` native)
   - **ollama/install.sh**: checks `ollama.env` exists, prints reminder if not

Key design: `settings.json`/`opencode.json`/`config.json` are **copied** so tools can modify freely without dirtying the repo. Re-running install.sh resets from repo version.

## `.stow-local-ignore` exclusions

Every package now has a `.stow-local-ignore` excluding at least its own `^/install\.sh`. Package-specific extras beyond that:

| Package         | Extra exclusions                                                            | Reason                                                          |
| --------------- | --------------------------------------------------------------------------- | --------------------------------------------------------------- |
| `claude/`       | guides, `pre_stow.sh`, `settings.json`, `settings.local.json`, `claude.env` | docs, installer-only, per-machine, or must be copied/gitignored |
| `opencode/`     | guides, `pre_stow.sh`, `opencode.json`                                      | docs, installer-only, or must be copied                         |
| `agents/`       | `ARCHITECTURE.md`                                                           | design doc, not deployed                                        |
| `nvim/`         | `.config/nvim/.claude/`                                                     | per-project Claude settings, not deployed                       |
| `ollama/`       | `.gitignore`, `ollama.env`                                                  | not meant to be symlinked out                                   |
| `zsh/`          | `.gitignore`                                                                | not meant to be symlinked out                                   |
| `bettercmdtab/` | `config.json`                                                               | must be copied (live two-way sync)                              |

## Task→Package map

| Task                                   | Which package to touch                                                               |
| -------------------------------------- | ------------------------------------------------------------------------------------ |
| Change shell prompt/alias/env          | `zsh/` (aliases.zsh, .zshrc, .zshenv)                                                |
| Change terminal (font, theme, bg)      | `ghostty/` or `kitty/`                                                               |
| Change tmux keybind/layout             | `tmux/` (tmux.conf)                                                                  |
| Change Neovim plugin/setting           | `nvim/` (lua/plugins/_.lua or lua/config/_.lua)                                      |
| Add/update AI agent def                | `claude/.claude/agents/` (+ mirror in opencode if OpenCode needs it)                 |
| Add/update AI skill                    | `claude/.claude/skills/<name>/SKILL.md`                                              |
| Add/update AI hook                     | `claude/.claude/hooks/`                                                              |
| Change tool permissions                | `claude/.claude/settings.json` + mirror in `opencode/.config/opencode/opencode.json` |
| Change shared agent rules (both tools) | `agents/.agents/AGENTS.md`                                                           |
| Bootstrap a new machine                | `install.sh` (repo root)                                                             |
| Add new stow package                   | Create `<name>/` dir, add to `install.sh` stow list                                  |

## Non-package repo items

| Path                    | Purpose                                                                                                                                                                                                                                                                                                                                 |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.worktrees/`           | Shared Claude Code / OpenCode session worktrees (not stowed)                                                                                                                                                                                                                                                                            |
| `.gitignore`            | Excludes `.gitconfig`, `claude/.claude/claude.env`, `**/settings.local.json`, `.worktrees/`, `.stow_blacklist.local`                                                                                                                                                                                                                    |
| `install.sh`            | Bootstrap entry point (repo root)                                                                                                                                                                                                                                                                                                       |
| `.stow_blacklist.local` | Optional, gitignored, per-machine opt-out for `install.sh`: one package directory name per line (blank lines and `#` comments ignored). Listed packages are filtered out of `install.sh`'s `directories` array before anything runs, so they get no `pre_stow.sh`, no `stow`, and no per-package `install.sh` — not created by default  |
| `.ready-tmux`           | Script: opens nvim in tmux split layout. `tmux/`'s `ready-tmux` looks for it in the cwd, so it only fires inside this repo — nothing stows it to `$HOME`                                                                                                                                                                                |
| `_ai-agent-patterns/`   | Reference notes on agent patterns (tracked, not stowed)                                                                                                                                                                                                                                                                                 |
| `_codecompanion/`       | WIP plan for the nvim CodeCompanion rebuild (tracked, not stowed). `README.md` first; `findings.md` holds all measured evidence and is cited by the numbered step files, which are one self-contained work packet each. Step `00` strips the existing integration, so steps run in order from a clean slate                             |
| `.opencode/`            | OpenCode's project-local dir, created when OpenCode runs here. Its own `.opencode/.gitignore` (tracked) excludes the generated `node_modules`/`package.json`/`package-lock.json`/`bun.lock` plus `state/` and `plans/`; the seven config subdirs (`agents`, `commands`, `modes`, `plugins`, `skills`, `tools`, `themes`) stay trackable |

## Non-stowed config files (per-machine)

- `~/.claude.json` — Claude Code user-level settings (editorMode set by install.sh)
- `~/.gitconfig` — git config (excluded from repo via .gitignore, created manually)
- `~/.config/ollama/ollama.env` — Ollama API key (gitignored, template provided)
- `~/.config/opencode/opencode.json` — copied from repo (tool may modify)
- `~/.claude/settings.json` — copied from repo (tool may modify)
- `~/.config/bettercmdtab/config.json` — copied from repo (app writes back live)
