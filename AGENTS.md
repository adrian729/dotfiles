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

- Keep Stow's `--no-folding`: folded parent symlinks expose even ignored files to tool writes inside the repo. Existing folds need unstowing and restowing; the flag alone does not repair them.
- Exclude installers, installer helpers, docs, secrets and copied configs in each package's `.stow-local-ignore`. Every package excludes its own `install.sh`.
- Claude `settings.json`, OpenCode `opencode.json`, Codex `config.toml`, and BetterCmdTab `config.json`/`schema.json` are regular copies, not symlinks. Tools can modify their live copies without dirtying git. Codex reinstalls retain selected local integration entries; other Codex preferences come from the repo.
- Keep machine-local shell configuration out of tracked files. Preserve existing `~/.zshrc` on install; use the local override paths documented in `zsh/install.sh` and the shell startup files.
- Source `lib/common.sh` for platform and dependency helpers. Use `is_macos`/`is_linux`, `ensure_cmd` for Homebrew tools, and `pkg_install`/`pkg_available` for distro integration; do not hardcode a Linux package manager at call sites.
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
