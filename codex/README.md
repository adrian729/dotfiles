# Codex

Edit `.codex/config.toml` here to choose portable defaults. The root installer includes this package on macOS and Linux. `codex/install.sh` installs the CLI if needed and atomically copies the config to `${CODEX_HOME:-$HOME/.codex}/config.toml`; Stow does not link the config. It also installs ShellCheck for shell-script diagnostics and Playwright CLI for browser automation.

Re-running the installer resets general settings to the repo version while preserving locally added integrations. `merge_config.py` reads both TOML files and carries forward:

- MCP servers (`mcp_servers`), plugins (`plugins`), marketplace sources (`marketplaces`), and app controls (`apps`).
- MCP OAuth storage/callback settings and enterprise managed authentication.
- Per-skill enablement entries (`skills.config`), matched by skill path.

The repo wins when it defines the same named integration or skill path; that complete entry replaces the local one. Other local entries survive, including their enabled/disabled state and tool permissions. General settings such as model, compaction, UI, project trust, feature flags, and skill context budgets are replaced by the repo defaults. Add those preferences here if you want them to persist. To remove a local integration, remove it from the live config using Codex or your editor; the installer does not maintain a separate registry that would restore it.

Credentials, sessions, downloaded plugins, and locally installed skills stay outside the repo and are not touched. No extra local config file is needed: use Codex normally to add integrations. Python 3.11+ is required for TOML parsing. Invalid TOML aborts installation without replacing the live config; successful writes are atomic and private (mode `600`). A symlinked config directory or a target inside this repo is rejected to prevent writing local state into a folded Stow package. TOML values are preserved, but comments and formatting in the live file are regenerated.

## Choose settings

The selected defaults are `gpt-6.1-sol` with `high` reasoning, full filesystem and network access, no command approval prompts, live web search, and Vim normal mode.

| Setting | Choices | What it controls |
| --- | --- | --- |
| `model` | A model available to your account, or omit the setting | Default model. The existing machine uses `gpt-6.1-sol`. |
| `model_reasoning_effort` | `low`, `medium`, `high`, or other values supported by the model | Reasoning effort; higher effort usually spends more time on the task. |
| `model_auto_compact_token_limit` | Token count, or omit for the model default | Currently `150000`; triggers automatic history compaction during a run. |
| `model_post_turn_compact_threshold_percent` | `0`–`100`; omit or `0` to disable | Currently `40`; additionally triggers compaction after a final response when usage reaches that percentage of the usable context window. |
| `approval_policy` | `on-request` or `never` | Whether Codex can ask to run commands beyond its current permissions. `never` alone does not grant additional access. |
| `sandbox_mode` | `read-only`, `workspace-write`, `danger-full-access` | Which filesystem writes and command networking the sandbox allows. |
| `sandbox_workspace_write.network_access` | `true` or `false` | Shell command networking in workspace mode; independent of web search. |
| `web_search` | `live`, `cached`, `indexed`, `disabled` | Web retrieval mode. |
| `tui.vim_mode_default` | `true` or `false` | Start the composer in Vim normal mode; `/vim` toggles it for the session. |
| `tui.status_line` | Ordered list of footer item identifiers | The baseline shows model with reasoning, context used, five-hour limit, weekly limit, current directory, Git branch, branch changes, and thread name, in that order. |

Use `/statusline` to change the footer interactively. Codex saves the selection in the live config; copy its `tui.status_line` list into this package's config to make those choices the defaults for future installs.

The compaction overrides are unbenchmarked choices, not established quality or usage optimizations. Earlier compaction reduces subsequent context size but adds compaction work and can reduce prompt-cache reuse. See the [setting definitions](https://developers.openai.com/codex/config-schema.json) and [cache/compaction tradeoff](https://developers.openai.com/api/docs/guides/prompt-caching#gotchas).

Optional later additions include `personality`, TUI themes and status lines, MCP servers, and credential storage preferences. Keep machine-specific project paths and connection details out of the portable baseline. See the [config basics](https://learn.chatgpt.com/docs/config-file/config-basic) and [full reference](https://learn.chatgpt.com/docs/config-file/config-reference).

## Shared skills

The `agents/` Stow package owns the original `agents/.agents/skills/markdown-no-wrap/SKILL.md` and deploys it to `~/.agents/skills/`, where Codex discovers it. Claude's `markdown-no-wrap/SKILL.md` is a symlink to the same original. The skill keeps each Markdown paragraph, list item, or blockquote on one physical line while preserving code fences, tables, and headings. Codex can choose it for Markdown edits, or you can invoke it with `$markdown-no-wrap`.

This package does not add a global `AGENTS.md`, custom agents, or hooks.

`ai-instruction-file-authoring` also lives under `agents/.agents/skills/` with a Claude discovery symlink. It provides the same instruction-file review workflow to Codex, Claude and OpenCode. Edit the shared original to keep them consistent.

## Browser automation

`install_playwright.sh` installs Microsoft's [`@playwright/cli`](https://github.com/microsoft/playwright-cli), its Chromium browser, and the upstream `playwright-cli` skill under `${CODEX_HOME:-$HOME/.codex}/skills/`. The skill and browser downloads stay outside git. Existing skill files and Playwright configuration are preserved on reinstall. Node.js 18+ and npm are required; the script uses the shared `ensure_node` helper.

The CLI runs headless with an in-memory browser profile by default. The installer creates `~/.playwright/cli.config.json` only when absent, selecting the downloaded Chromium so no system Chrome installation is required. Project `.playwright/cli.config.json` files or `--config` can override it. No MCP server or browser extension is needed.

Ask Codex to use `$playwright-cli` to inspect a page, exercise a user flow, or take a screenshot. You can also run it directly:

```sh
playwright-cli open https://example.com
playwright-cli snapshot
playwright-cli screenshot --filename=page.png
playwright-cli close
```

Use `open --headed` to see the browser on a machine with a graphical session. Screenshots and snapshots are written to the current project; keep generated `.playwright-cli/` output and saved authentication state out of git.

To install or repair browser support without resetting Codex settings, run `bash codex/install_playwright.sh`. To update the CLI explicitly, run `npm install -g @playwright/cli@latest`, then rerun that script to download the matching browser. Existing skill copies are preserved; to refresh the skill too, move `${CODEX_HOME:-$HOME/.codex}/skills/playwright-cli` aside before rerunning. On Linux, missing browser libraries are reported by Playwright; install the reported dependencies for your distribution before retrying.

## Apply Codex and its shared skills

From the repo root:

```sh
stow --no-folding -t "$HOME" codex agents
bash codex/install.sh
```

Restart Codex after applying the config. On a new machine, run `codex login` separately.
