# Dotfiles

GNU Stow packages deploy files to `~`. `install.sh` selects packages, stows them, then runs each successful package's installer. `lib/`, `tests/`, and underscore-prefixed reference directories are not packages.

## Where changes belong

| Area | Repo path |
| --- | --- |
| Shared AI skills | `agents/.agents/skills/<name>/SKILL.md` |
| Shared Claude/OpenCode instructions | `agents/.agents/AGENTS.md` |
| Claude config, agents, skills and hooks | `claude/.claude/` |
| Claude and local LLM scripts | `claude/.local/scripts/` |
| Claude's local plugin marketplace | `claude/marketplace/` |
| OpenCode config and agents | `opencode/.config/opencode/` |
| OpenCode model selection and scripts | `opencode/.local/{config,scripts}/` |
| Codex defaults and installation | `codex/` (see `codex/README.md`) |
| Neovim | `nvim/.config/nvim/` |
| Shell | `zsh/.config/zsh/` |
| tmux | `tmux/.config/tmux/`, `tmux/.local/scripts/` |
| Terminal, file manager and clangd | `{ghostty,kitty,lf,clangd}/.config/` |
| Ollama client config and scripts | `ollama/.config/ollama/`, `ollama/.local/scripts/` |
| BetterCmdTab | `bettercmdtab/.config/bettercmdtab/` |

Root `.claude/` holds project instructions only; it is not Claude's deployment directory. Shared skills have one original under `agents/` and symlinks in other tools' discovery directories. Codex discovers `~/.agents/skills/` directly and deliberately has no global `AGENTS.md` link, custom agents, or hooks.

## Installation invariants

- Keep Stow's `--no-folding`: folded parent symlinks expose even ignored files to tool writes inside the repo. The flag alone does not repair an existing fold, so root `install.sh` restows (`-R`), which unstows first.
- Exclude installers, installer helpers, docs, secrets and copied configs in each package's `.stow-local-ignore`. Every package excludes its own `install.sh`.
- Claude `settings.json`, OpenCode `opencode.json`, Codex `config.toml`, and BetterCmdTab `config.json`/`schema.json` are regular copies, not symlinks. Tools can modify their live copies without dirtying git. Codex reinstalls retain selected local integration entries and Claude reinstalls retain the `/model` selection; other preferences come from the repo.
- Keep machine-local shell configuration out of tracked files; it belongs in `~/.local/.local_profile`, which `.zshrc` sources last, in interactive shells only. The stowed `~/.zshenv` sets `ZDOTDIR`, after which zsh ignores `~/.zshrc` and `~/.zprofile`. `zsh/pre_stow.sh` therefore copies a legacy `~/.zshenv`, `~/.zprofile` and `~/.zshrc` into the local profile once, listing them in `~/.local/state/dotfiles/zsh-migrated` so that pruning the copy is not undone. It leaves the last two in place, and moves `~/.zshenv` to a backup only after a stow dry run shows nothing else blocks the package. PATH order is set in `$ZDOTDIR/.zshenv` and re-applied in `.zprofile`, because macOS `path_helper` reorders it for login shells; `.zshrc` puts `~/.local/{scripts,bin}` back in front after the local profile.
- Source `lib/common.sh` for platform and dependency helpers. Use `is_macos`/`is_linux`, `ensure_cmd` for CLI tools, `ensure_cask` for macOS apps, and `pkg_install`/`pkg_available` for distro integration; do not hardcode a Linux package manager at call sites.
- Homebrew no longer builds bottles for Intel macOS, where a source build can pull in rust, llvm or go. `ensure_cmd` pours a bottle only when `brew_can_pour` confirms one for this machine, otherwise installs the project's release build through `prebuilt_install` into `~/.local/bin`, and builds from source only for tools without one. `prebuilt_install` returns 2 only for a tool without an entry and 1 for any failure, so a failed download never starts a source build. A new tool with a heavy build needs a `prebuilt_install` entry covering macOS and Linux on both x86_64 and arm64.
- Packages support macOS and Linux. The intentional macOS-only packages (`bettercmdtab`, `kitty`) require both an entry in root `install.sh`'s `macos_only` and their own platform guard.
- Root installation runs a package's `pre_stow.sh` before stowing, skips failed packages, and reports failures while continuing others. Keep package-specific preparation in that package.

## Cross-file dependencies

- Claude and OpenCode share named worktrees at `.worktrees/<name>/`, but retain separate AI sessions.
- Translate shared permission changes between Claude's `permissions` and OpenCode's `permission` schemas. Preserve intentional tool-specific exceptions. OpenCode agent-level bash permissions replace the top-level block; keep the deny lists in `debugger`, `implementer`, and `implementer-quick` aligned.
- OpenCode's model map is `opencode/.local/config/opencode-models.json`. Keep every pinned agent covered, free candidates explicit, and the relay preferences aligned. Probes must retain explicit free pins on failure instead of falling through to a potentially paid default. Update the dated `MODELS.md` reference when changing the catalog. Adding a provider requires checking its authorization and limits.
- Claude's `skillOverrides: name-only` saves discovery context; it does not enforce explicit invocation. The four workflow skills (`audit-loop`, `autonomous-process`, `best-of-n`, `evaluator-optimizer`) require an explicit request in their instructions. Current settings register no steering hooks; old hook files are compatibility stubs.
- Keep Neovim's lazy.nvim `dev.fallback = true`: `adrian729/ducktape.nvim` uses `~/projects/ducktape.nvim` when present and otherwise clones from GitHub. `_ducktape/STATE.md` and `PLAN.md` describe that extraction; read them when working on it.

## Validation

Offline regressions live in `tests/`: `python3 -m unittest discover -s tests -v`. Run the relevant test module for scoped changes. For installation changes, use temporary target homes and fake external tools; running root `install.sh` changes the actual machine.
