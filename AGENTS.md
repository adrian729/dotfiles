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
- Root `install.sh` stows with **`--no-folding`**, and must keep doing so. Without it, stow "folds" an entire directory into one symlink whenever the target does not exist yet — on a fresh machine `~/.config` itself becomes a link into this repo. That defeats the whole copied-not-symlinked design: `claude/.claude/settings.json`, `opencode.json` and `bettercmdtab/config.json` become live repo files, so each tool writes its own state straight into git. A `.stow-local-ignore` entry does **not** protect against this — ignoring a file stops stow linking it individually, not the parent fold that exposes it anyway. Verified by experiment, and observed in the wild: `~/.config/bettercmdtab` on the original Mac was a folded symlink into the repo, and BetterCmdTab had been writing `config.json` (and a stray `schema.json`) into the working tree through it. Adding the flag does not un-fold an already-folded target — that needs `stow -D <pkg>` followed by a normal re-stow.
- `install.sh` at repo root is the bootstrap installer. `lib/common.sh` holds the shared OS-switch and dependency helpers every installer sources — put platform branching there rather than re-deriving it per package, and detect the platform with its `is_macos`/`is_linux` rather than `$OSTYPE`.
- Every package must work on macOS **and** Linux — **any** Linux, not one distro. Never hardcode a package manager: go through `pkg_install`/`pkg_available`, which dispatch to apt/dnf/yum/zypper/pacman/apk and degrade to an actionable warning on anything unrecognised. Where a distro genuinely needs different treatment (toolchain groups, ghostty's packaging), branch on `pkg_mgr` inside the helper rather than at the call site. A package that genuinely cannot exist on Linux goes in root `install.sh`'s `macos_only` array *and* keeps its own `is_macos ||` early-exit guard — the array is what stops it being stowed, the guard is what protects a direct `bash <pkg>/install.sh`. Both currently list `bettercmdtab` (no Linux equivalent) and `kitty` (deliberate choice: ghostty is the Linux terminal).
- Worktrees for claude and opencode share a single root: `.worktrees/<name>/` — either tool can attach to the same worktree/branch/color under one name. Each tool still tracks its own AI conversation state (Claude via `~/.claude/projects/`, OpenCode via its own session DB + the `wt.<name>.session` git-config key) — sharing a name shares the checkout, not a single AI session.
- OpenCode's agent-level `permission.bash` block fully replaces (does not merge with) `opencode.json`'s top-level one, so the 7-pair bash deny list (`git push`/`npm publish`/`gh release`/`docker push`/`terraform apply`/`kubectl apply`/`cargo publish`) is duplicated verbatim across `opencode.json` and `opencode/.config/opencode/agents/{debugger,implementer,implementer-quick}.md`. Since `opencode.json` is plain JSON (no comments to flag this), if you add to the deny list in one place, add it in all four.
- When `claude/.claude/settings.json`'s `permissions` block changes, mirror the same rule into `opencode/.config/opencode/opencode.json`'s `permission` block, translated into OpenCode's own schema (bash sub-command patterns, three-state `allow`/`ask`/`deny`). Keep OpenCode's permissive `"*": "allow"` bash default as the baseline unless a change explicitly says otherwise. Exception, deliberately not mirrored: Claude's `allow` list explicitly allowlists `Bash(opencode-task*)`/`Bash(opencode-llm*)` so Claude can shell out to OpenCode; OpenCode has no equivalent entry, since it shouldn't shell out to itself (enforced today only by the `opencode-task`/`opencode-llm` skills' own anti-triggers, not a permission rule). Second exception, also deliberate: `npm publish`/`gh release`/`docker push`/`terraform apply`/`kubectl apply`/`cargo publish` are `ask` in `claude/.claude/settings.json` but `deny` in `opencode.json` — Claude's `ask` works because a human is present to answer the prompt, but OpenCode's unattended `--auto` runs have nobody to ask, so the equivalent safety there is a hard `deny`, not a translated `ask`. Don't "fix" this by loosening opencode.json's `deny` back to `ask`.
- Every OpenCode agent that needs a pinned model must have an entry in `opencode/.local/config/opencode-models.json`'s `agents` map: `opencode-agent-models-probe` only iterates that map's keys, and `opencode/install.sh` jq-merges the resulting `{agent: {<name>: {model: …}}}` into the copied `~/.config/opencode/opencode.json`. An agent missing from the map gets no `model` and falls through to OpenCode's ambient default, which may be a paid model. All 10 agents are covered. `relay`'s list duplicates the top-level `relay` key, which is a different mechanism (`opencode-llm` reads that one to build its `-m` fallback walk) — keep the two in sync, or drop the `agents` entry if the duplication ever drifts. Paid (`opencode-go/*`) entries inside a list are inert ranking hints: the probe skips any candidate that isn't also in `free_models`, so a list can express preference order without ever selecting a paid model.
- The free tier rotates often, and a stale entry is a **silent** failure: when the only free model in an agent's list is retired, the probe writes no override at all, that agent falls through to the ambient default (possibly paid), and — worse — `task`/`opencode-task` subagent spawns start failing outright with `Model not found`. `opencode-agent-models-probe` now warns on stderr both for agents left unpinned and for `free_models` entries missing from the live catalog, so a rotation is caught by running the probe rather than by a broken spawn. **Every agent list must contain at least one free model that `opencode models opencode` actually returns**; when the free tier rotates, update `free_models`, every `agents` list, and `MODELS.md` together, then re-run the probe and confirm all 10 agents got a pin. `MODELS.md` is the data source for every price, limit, and spec — refresh it from opencode.ai/docs/zen + /docs/go (limits and Req/mo) and models.dev/api.json (context/output/modality, which the docs pages do not publish).
- `ollama-cloud` is deliberately absent from `free_models` and every `agents` list: the provider is still upstream but needs `OLLAMA_API_KEY`, and it is not connected on this machine, so the probe cannot see it. `MODELS.md` keeps the full 24-model catalog as reference. Re-add after `/connect` if you want it. `model-fallback.js` independently filters the `ollama-cloud/` prefix out of the fallback path.
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
    scripts/           claude-wt, git-wt, llm, llm-models-probe,
                       llm-probe, open-wt, opencode-llm, opencode-task
  marketplace/         local Claude Code plugin marketplace "dotfiles" (.stow-local-ignored,
                       registered in place by install.sh): plugins/ty-lsp (Python LSP via ty)
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
    plugins/           model-fallback.js (auto-loaded; resends rate-limited
                       sessions on a free model — `opencode/*-free` only,
                       never ollama-cloud which rate-limits too)
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
  .local/scripts/      ollama-ctl, llm-models-pull
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
  install.sh           macOS-only (is_macos guard + root install.sh's macos_only)

lib/                   not a stow package — shared installer helpers only
  common.sh            sourced by root install.sh and every package install.sh
```

## install.sh flow (repo root)

0. Sources `lib/common.sh` (see below) and `cd`s to the repo root, so every path in the script is repo-relative regardless of the caller's cwd
1. Bootstraps Homebrew via `brew_bootstrap` if missing, then verifies/installs `stow` (falling back to `pkg_install` if the Homebrew bootstrap failed — without stow nothing links at all, which is the difference between a partial install and one that achieves literally nothing). On Linux `brew_bootstrap` installs Homebrew's own prerequisites via `brew_prereqs` first, since the upstream installer checks for them but does not install them. Interactivity is left to that installer, which already sets `NONINTERACTIVE` itself when stdin is not a TTY.
2. Filters out packages that cannot exist on this platform via the `macos_only` array (`bettercmdtab`, `kitty`) when running on Linux, then applies `.stow_blacklist.local`. A package in both lists is announced once, with the platform reason taking precedence.
3. Stows the surviving packages from its `directories` array (or prompts per-package unless answering "y" to "stow all"), via a `stow_pkg` helper that runs the package's `pre_stow.sh` first if it has one. The stow call passes **`--no-folding`, which is load-bearing** — see the rule below. `pre_stow.sh` is for work that must happen while the target files are still unstowed — the two that exist (`claude/`, `opencode/`) delete the plain script copies `standalone_quick_setup.sh` leaves in `~/.local/scripts`, which stow would otherwise refuse to overwrite. Keep this hook generic in root `install.sh`; package-specific logic belongs in the package's own `pre_stow.sh`. A failing `pre_stow.sh` warns and stows anyway.
4. Runs each package's own `install.sh` if present — all 12 packages have one now, mostly an idempotent `ensure_cmd <tool> [formula]` guard (`agents/install.sh` is a no-op placeholder). Notable exceptions:
   - **claude/install.sh**: also installs the `claude` CLI itself (brew cask on macOS, `claude.ai/install.sh` on Linux — the cask does ship Linux variants now, but the official installer is Anthropic's documented Linux path and self-updates), copies `settings.json` (not symlink → tool can modify freely), sets `editorMode: "vim"` in `~/.claude.json`, probes local LLM (llm-models-probe warns when the catalogued lineup is missing — fix by running `llm-models-pull` manually), then registers `claude/marketplace/` via `claude plugin marketplace add` and installs `ty-lsp@dotfiles` (CLI rather than `extraKnownMarketplaces` in the repo settings.json, because the directory source needs a per-machine absolute path; must run after the settings copy, which it writes into). The plugin is copied into `~/.claude/plugins/cache` and `claude plugin update` is version-gated, so edits under `claude/marketplace/plugins/ty-lsp/` only take effect after bumping its `version` or running `claude plugin uninstall ty-lsp@dotfiles && claude plugin install ty-lsp@dotfiles`. Uses `ensure_node` rather than a bare `command -v npm` before installing `claude-agent-acp`: npm only happens to be on PATH there because `opencode/` installs first and brew's `opencode` formula depends on `node`, so the bare check is silently load-bearing on the order of the `directories` array.
   - **opencode/install.sh**: copies `opencode.json` (not symlink), probes free-tier model availability
   - **bettercmdtab/install.sh**: macOS-only; brew-installs `bettercmdtab`, copies `config.json` (not symlink → app writes back live), sets trigger hotkeys via `defaults write` (⌥Tab/⌥` to leave ⌘Tab/⌘` native)
   - **ghostty/install.sh**: brew cask on macOS; on Linux tries the distro's own package (official on Arch `extra`, Alpine testing, Gentoo, Void, Solus, NixOS) → the `mkasberg/ghostty-ubuntu` .deb, Debian family only → the `--classic` snap, which upstream builds from Ghostty's own scripts. Fedora has only a community COPR, which is printed as a suggestion rather than enabled automatically; there is no Flathub package, so Flatpak is deliberately not attempted.
   - **kitty/install.sh**: macOS-only by choice, not by packaging limit — ghostty is the sole Linux terminal. Listed in root `install.sh`'s `macos_only`; changing that means changing both.
   - **ollama/install.sh**: brew on macOS; on Linux the official `ollama.com/install.sh`, which registers the systemd unit and pulls the CUDA/ROCm runtime that the Homebrew build does not set up. Checks `ollama.env` exists and prints a reminder if not.
   - **zsh/install.sh**: installs `zsh` itself from the distro on Linux (never from brew — a login shell under `/home/linuxbrew` locks the account out if that tree goes missing) and offers `chsh`, since a fresh Linux account is usually on bash and would leave this whole package inert. The offer only ever names an OS-owned zsh (`/bin/zsh`, `/usr/bin/zsh`), never whatever `command -v zsh` resolves to — after `brew_shellenv` that is Homebrew's, and pointing a login shell there is the same lock-out.

Key design: `settings.json`/`opencode.json`/`config.json` are **copied** so tools can modify freely without dirtying the repo. Re-running install.sh resets from repo version.

## `lib/common.sh` (shared installer helpers)

Sourced, never executed. Root `install.sh` reaches it as `$(dirname "$0")/lib/common.sh`; every package installer as `$(dirname "$0")/../lib/common.sh` — which also resolves correctly for `clangd/install.sh` when `nvim/install.sh` sources it, because both packages sit one level deep. A `DOTFILES_COMMON_SH` guard makes double-sourcing a no-op.

Homebrew is the primary package manager on **both** platforms; all 22 formulae the repo installs have `x86_64_linux`/`arm64_linux` bottles. The distro's own package manager is used only for things that are inherently system integration and that brew either cannot provide or should not own: Homebrew's own build prerequisites (brew cannot install what it needs in order to exist), the display-server clipboard bridges, `fontconfig`, the C toolchain, and the login shell.

| Helper | What it does |
| --- | --- |
| `is_macos` / `is_linux` | Platform test off `uname -s`. Use these, never `$OSTYPE` — that is baked in at bash build time and so is invisible to the rest of the OS-switch machinery. |
| `have` / `info` / `warn` / `interactive` / `confirm` | Small shared primitives. `confirm` answers "no" when there is no tty, so unattended runs never block. |
| `pkg_mgr` | The system package manager, detected by which *binary* exists (apt-get → dnf → yum → zypper → pacman → apk), not by `/etc/os-release` ID — derivatives are the common case and report their own ID. Memoised in `_PKG_MGR`. |
| `pkg_install PKG...` | Install distro packages by their common name, dispatching on `pkg_mgr`. `_pkg_name` translates only the names that actually differ (today just `procps` → `procps-ng` on dnf/yum/pacman). Refreshes the apt index once per *process* — root `install.sh` runs each package installer as its own `bash`, so that dedupe is per-script, not per-run. Returns non-zero on an unrecognised distro so callers degrade to a warning. |
| `pkg_available PKG` | Whether the distro's own repos offer PKG, asked before installing so a missing package becomes a fallback rather than an error. Used by ghostty, whose packaging differs wildly per distro. |
| `brew_prereqs` | Homebrew's documented build prerequisites per family (Debian `build-essential procps curl file git`; Fedora/RHEL and openSUSE take the toolchain as a group/pattern via `ensure_build_tools`, then `procps curl file git`; Arch `base-devel procps-ng …`; Alpine `build-base …`). Homebrew checks for these but does not install them, and on a fresh machine `curl` is often missing — which kills the upstream installer on its own first line. |
| `run_remote_installer URL` | Download a remote install script, run it, return its real exit status. Both obvious spellings lie: `curl \| sh` reports only `sh`'s status (and `sh` on empty input exits 0), and `bash -c "$(curl …)"` discards curl's status (`bash -c ""` exits 0) — so a 404 or an offline machine reads as a successful install and every `\|\| warn` after it is dead code. Use this for every `curl`-to-shell install; never re-introduce the pipe form. |
| `brew_bin` / `brew_shellenv` / `brew_bootstrap` | Resolve/activate/install Homebrew. Every caller resolves brew through these rather than assuming it is already on PATH — it is not during the run that installs it. |
| `ensure_cmd CMD [FORMULA]` | brew-install FORMULA (default CMD) unless CMD already resolves. The split matters for formulae named differently from their binary (`rg`/`ripgrep`). |
| `ensure_build_tools` | C toolchain + make, for nvim-treesitter's parser compilation and telescope-fzf-native's `make` build step. Xcode CLT hint on macOS, `build-essential` on Linux. |
| `ensure_clipboard` | Installs `wl-clipboard` + `xclip` on Linux (both, since the session type at install time need not match the session actually used). macOS has `pbcopy` built in. Without this, tmux's copy binding and nvim's `clipboard=unnamedplus` silently do nothing. |
| `ensure_nerd_font` | FiraCode Nerd Font. `starship.toml`, `eza --icons`, `lf`'s icons and the tmux status bar all render Nerd glyphs; without a patched font every one of them shows tofu. Cask on macOS, nerd-fonts release zip into `~/.local/share/fonts` + `fc-cache` on Linux. |
| `ensure_node` | npm for the global CLIs (`claude-agent-acp`). nvm owns node on both platforms so there is one version manager rather than a brew node racing an nvm node on PATH. Callers must not assume `.zshrc`'s lazy nvm shim exists — installers run in non-interactive bash. |

## `.stow-local-ignore` exclusions

Every package now has a `.stow-local-ignore` excluding at least its own `^/install\.sh`. Package-specific extras beyond that:

| Package         | Extra exclusions                                                            | Reason                                                          |
| --------------- | --------------------------------------------------------------------------- | --------------------------------------------------------------- |
| `claude/`       | guides, `pre_stow.sh`, `settings.json`, `settings.local.json`, `claude.env`, `marketplace/` | docs, installer-only, per-machine, must be copied/gitignored, or registered in place |
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
| Add a macOS/Linux switch or shared dep | `lib/common.sh` (then call the helper from the package's `install.sh`)               |
| Make a package macOS-only              | `install.sh`'s `macos_only` array **and** an `is_macos` early-exit guard in its own `install.sh` |

## Non-package repo items

| Path                    | Purpose                                                                                                                                                                                                                                                                                                                                 |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.worktrees/`           | Shared Claude Code / OpenCode session worktrees (not stowed)                                                                                                                                                                                                                                                                            |
| `.gitignore`            | Excludes `.gitconfig`, `claude/.claude/claude.env`, `**/settings.local.json`, `.worktrees/`, `.stow_blacklist.local`                                                                                                                                                                                                                    |
| `install.sh`            | Bootstrap entry point (repo root)                                                                                                                                                                                                                                                                                                       |
| `.stow_blacklist.local` | Optional, gitignored, per-machine opt-out for `install.sh`: one package directory name per line (blank lines and `#` comments ignored). Listed packages are filtered out of `install.sh`'s `directories` array before anything runs, so they get no `pre_stow.sh`, no `stow`, and no per-package `install.sh` — not created by default  |
| `.ready-tmux`           | Script: opens nvim in tmux split layout. `tmux/`'s `ready-tmux` looks for it in the cwd, so it only fires inside this repo — nothing stows it to `$HOME`                                                                                                                                                                                |
| `_ai-agent-patterns/`   | Reference notes on agent patterns (tracked, not stowed)                                                                                                                                                                                                                                                                                 |
| `_ducktape/`            | Extraction of the nvim CodeCompanion layer into the standalone `ducktape.nvim` plugin (tracked, not stowed). `PLAN.md` is the approved specification; `STATE.md` records what is actually built, what was learned, and what comes next — read `STATE.md` first to find the current position, then `PLAN.md` for the target             |
| `lib/`                  | Shared installer helpers (`common.sh`), sourced by root `install.sh` and every package `install.sh`. Not a stow package and never stowed — see the `lib/common.sh` section above                                                                                                                                                        |
| `.opencode/`            | OpenCode's project-local dir, created when OpenCode runs here. Its own `.opencode/.gitignore` (tracked) excludes the generated `node_modules`/`package.json`/`package-lock.json`/`bun.lock` plus `state/` and `plans/`; the seven config subdirs (`agents`, `commands`, `modes`, `plugins`, `skills`, `tools`, `themes`) stay trackable |

## Non-stowed config files (per-machine)

- `~/.claude.json` — Claude Code user-level settings (editorMode set by install.sh)
- `~/.gitconfig` — git config (excluded from repo via .gitignore, created manually)
- `~/.config/ollama/ollama.env` — Ollama API key (gitignored, template provided)
- `~/.config/opencode/opencode.json` — copied from repo (tool may modify)
- `~/.claude/settings.json` — copied from repo (tool may modify)
- `~/.config/bettercmdtab/config.json` — copied from repo (app writes back live)
