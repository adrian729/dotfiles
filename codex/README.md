# Codex

Edit `.codex/config.toml` here to choose portable defaults. The root installer includes this package on macOS and Linux. `codex/install.sh` installs the CLI if needed and atomically copies the config to `${CODEX_HOME:-$HOME/.codex}/config.toml`; Stow does not link the config.

Re-running the installer replaces the entire live config with the repo version, including any locally added project trust, MCP, plugin, and interface settings. Save your existing config before applying the package if you want to retain those settings. Credentials, sessions, and downloaded plugins are not packaged.

## Choose settings

The selected defaults are `gpt-6.1-sol` with `high` reasoning, full filesystem and network access, no command approval prompts, live web search, and Vim normal mode.

| Setting | Choices | What it controls |
| --- | --- | --- |
| `model` | A model available to your account, or omit the setting | Default model. The existing machine uses `gpt-6.1-sol`. |
| `model_reasoning_effort` | `low`, `medium`, `high`, or other values supported by the model | Reasoning effort; higher effort usually spends more time on the task. |
| `approval_policy` | `on-request` or `never` | Whether Codex can ask to run commands beyond its current permissions. `never` alone does not grant additional access. |
| `sandbox_mode` | `read-only`, `workspace-write`, `danger-full-access` | Which filesystem writes and command networking the sandbox allows. |
| `sandbox_workspace_write.network_access` | `true` or `false` | Shell command networking in workspace mode; independent of web search. |
| `web_search` | `live`, `cached`, `indexed`, `disabled` | Web retrieval mode. |
| `tui.vim_mode_default` | `true` or `false` | Start the composer in Vim normal mode; `/vim` toggles it for the session. |
| `tui.status_line` | Ordered list of footer item identifiers | The baseline shows model with reasoning, context used, five-hour limit, weekly limit, current directory, Git branch, branch changes, and thread name, in that order. |

Use `/statusline` to change the footer interactively. Codex saves the selection in the live config; copy its `tui.status_line` list into this package's config to make those choices the defaults for future installs.

Optional later additions include `personality`, TUI themes and status lines, MCP servers, and credential storage preferences. Keep machine-specific project paths and connection details out of the portable baseline. See the [config basics](https://learn.chatgpt.com/docs/config-file/config-basic) and [full reference](https://learn.chatgpt.com/docs/config-file/config-reference).

## Markdown skill

The `agents/` Stow package owns the original `agents/.agents/skills/markdown-no-wrap/SKILL.md` and deploys it to `~/.agents/skills/`, where Codex discovers it. Claude's `markdown-no-wrap/SKILL.md` is a symlink to the same original. The skill keeps each Markdown paragraph, list item, or blockquote on one physical line while preserving code fences, tables, and headings. Codex can choose it for Markdown edits, or you can invoke it with `$markdown-no-wrap`.

This package does not add a global `AGENTS.md`, custom agents, or hooks.

## Apply Codex and its shared skill

From the repo root:

```sh
stow --no-folding -t "$HOME" codex agents
bash codex/install.sh
```

Restart Codex after applying the config. On a new machine, run `codex login` separately.
