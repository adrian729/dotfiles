---
name: claude-cli
description: Invoke the Claude Code CLI from another AI tool (OpenCode, Cursor, etc.), a shell script, or CI pipeline — non-interactive one-shot queries (pipe / `-p`), session lifecycle (continue/resume/fork), model/agent/effort dials, permission modes, output formats, MCP config, worktree management. Use when the caller needs flags, subcommands, env vars, config paths, or scripting patterns to spawn or interact with a `claude` process programmatically; NOT for configuring Claude Code's own settings/hooks/permissions (handle those declaratively in settings.json, not via CLI flags).
---

Claude Code CLI — the `claude` binary. Flags and positional prompt coexist in any order. `claude -p "do X"` is the scripting workhorse.

## Modes

| Mode | Invocation | Use case |
|---|---|---|
| Interactive | `claude` | Default: full terminal UI, turn-based conversation |
| One-shot | `claude -p "prompt"` / `echo "prompt" \| claude -p` | Non-interactive: print response to stdout, exit |
| Background | `claude --bg "task"` | Detached agent session, managed via `claude agents` |
| Minimal | `claude --bare` | Skip hooks, LSP, plugins, keychain, auto-memory, CLAUDE.md discovery |
| Safe | `claude --safe-mode` | Disable all customizations (troubleshooting) |

## Session lifecycle

| Flag | Action |
|---|---|
| `-c`, `--continue` | Resume most recent session in cwd |
| `-r`, `--resume [id]` | Resume by session ID, or open interactive picker |
| `--from-pr [number/url]` | Resume session linked to a PR |
| `--fork-session` | Create a new session ID when resuming (keeps origin clean) |
| `-n`, `--name <name>` | Human-readable display name for current session |
| `--session-id <uuid>` | Force a specific session UUID |
| `--no-session-persistence` | Don't save session to disk (one-shot only) |

## Model / agent / effort

| Flag | Description |
|---|---|
| `--model <model>` | Model alias or full name (e.g. `sonnet`, `opus`, `claude-sonnet-5`) |
| `--agent <name>` | Agent for the session (overrides `agent` setting). Accepts CLI built-in agents (e.g. `Explore`, `Plan`, `general-purpose` — exact set varies by version, see below) plus any custom agent defined in the current project's `.claude/agents/*.md` or a global `~/.claude/agents/` (a custom definition of the same name overrides the built-in). To get the live accepted list for the current install: pass any invalid name with `-p` (not `--help`, which skips validation) — e.g. `claude --agent x -p "hi"` — the CLI prints `not found. Available agents: ...` with the current roster |
| `--agents <json>` | Define ad-hoc agents inline: `'{"reviewer":{"description":"...","prompt":"You are..."}}'` |
| `--effort <level>` | Reasoning effort: `low`, `medium`, `high`, `xhigh`, `max` |
| `--betas <betas...>` | Beta feature headers (API-key users only) |

## Permissions / tools

| Flag | Description |
|---|---|
| `--permission-mode <mode>` | `acceptEdits`, `auto`, `bypassPermissions`, `manual`, `dontAsk`, `plan` |
| `--dangerously-skip-permissions` | Bypass all permission checks |
| `--allow-dangerously-skip-permissions` | Make bypass-selectable in UI, not default |
| `--allowed-tools <tools...>` | Allowlist: `"Bash(git *) Edit"` |
| `--disallowed-tools <tools...>` | Denylist |
| `--tools <tools...>` | Override full tool set |
| `--add-dir <dirs...>` | Extra directories for tool access (beyond cwd) |

## Prompt / system prompt

| Flag | Description |
|---|---|
| `--system-prompt <prompt>` | Replace default system prompt entirely |
| `--append-system-prompt <prompt>` | Append to default system prompt |
| `--json-schema <schema>` | JSON Schema for structured output validation |
| `--exclude-dynamic-system-prompt-sections` | Move per-machine sections to first user message |
| `--file <file_id:path...>` | Download file resources at startup |
| `--disable-slash-commands` | Disable all skills |

## Output format (one-shot mode)

| `--output-format` | Behavior |
|---|---|
| `text` (default) | Plain text response |
| `json` | Single JSON object with response and metadata |
| `stream-json` | Newline-delimited JSON events as they stream |

Additional output flags:

| Flag | Description |
|---|---|
| `--include-partial-messages` | Include partial message chunks (with `stream-json`) |
| `--include-hook-events` | Include hook lifecycle events (with `stream-json`) |
| `--input-format stream-json` | Accept streaming JSON input lines |
| `--replay-user-messages` | Echo user messages back on stdout (stream-json) |
| `--include-partial-messages` | Include partial message chunks as they arrive |
| `--prompt-suggestions [value]` | Enable/disable prompt suggestions |
| `--ax-screen-reader` | Screen-reader friendly output |

## MCP

| Command | Action |
|---|---|
| `claude mcp add <name> <cmdOrUrl> [args...] [-t/--transport stdio\|sse\|http]` | Add an MCP server (defaults to stdio; pass `--transport http`/`sse` for non-stdio servers) |
| `claude mcp add-json <name> <json>` | Add server by JSON config string |
| `claude mcp get <name>` | Show server details |
| `claude mcp list` | List configured servers |
| `claude mcp remove <name>` | Remove server |
| `claude mcp login <name>` | Authenticate with MCP server |
| `claude mcp logout <name>` | Clear OAuth credentials |
| `claude mcp serve` | Run Claude Code as an MCP server |

Runtime MCP via CLI flags:

| Flag | Description |
|---|---|
| `--mcp-config <configs...>` | Load MCP servers from JSON files or strings |
| `--strict-mcp-config` | Ignore all other MCP configs, use only `--mcp-config` |

## Worktree

| Flag | Description |
|---|---|
| `-w`, `--worktree [name]` | Create a git worktree and start a session in it |
| `--tmux` | Create a tmux session for the worktree — requires `--worktree` to already be set; defaults to iTerm2-native panes rather than classic tmux unless `--tmux=classic` is passed (relevant here since this repo's terminal stack is Ghostty/Kitty/tmux, not iTerm2) |

## Plugins

| Subcommand | Description |
|---|---|
| `claude plugin install <name>` | Install a plugin |
| `claude plugin uninstall <name>` | Remove a plugin |
| `claude plugin list` | List installed plugins |
| `claude plugin marketplace` | Manage marketplace sources (add/list/remove/update) — not for browsing plugins themselves (see `claude plugin list` above) |
| `claude plugin init` | Create a plugin scaffold |
| `claude plugin eval` | Evaluate plugin performance |

Runtime via CLI flags:

| Flag | Description |
|---|---|
| `--plugin-dir <path>` | Load plugin from directory or .zip (repeatable) |
| `--plugin-url <url>` | Fetch plugin .zip from URL (repeatable) |

## Other subcommands

| Command | Description |
|---|---|
| `claude auth login / logout / status` | Authentication management |
| `claude setup-token` | Create a long-lived OAuth token (for CI/automation) |
| `claude agents --json` | List background agent sessions as JSON |
| `claude doctor` | Check installation health |
| `claude ultrareview [target]` | Cloud-hosted multi-agent code review |
| `claude update` | Check for updates and install |
| `claude project purge [path]` | Wipe all Claude Code state for a project |
| `claude auto-mode config / critique / defaults` | Inspect auto-mode classifier |
| `claude gateway --config <path>` | Enterprise auth/telemetry gateway |

## Config file load order

Highest to lowest precedence:

1. Managed — `managed-settings.json` (MDM/enterprise policy); cannot be overridden
2. CLI args — `--settings <file-or-json>`
3. Local — `<repo>/.claude/settings.local.json` (project-scoped, gitignored, per-machine; note there is no user-global `settings.local.json` — this tier only exists at the project level)
4. Project — `<repo>/.claude/settings.json` (team-shared)
5. User — `~/.claude/settings.json` (lowest precedence)

`--setting-sources <sources>` is a separate load-filter, not a precedence tier: it controls which of `user`, `project`, `local` sources get read at all.

## Key environment variables

| Variable | Purpose |
|---|---|
| `CLAUDE_CODE_OAUTH_TOKEN` | Long-lived auth token (from `claude setup-token`); not read by `--bare` — that mode needs `ANTHROPIC_API_KEY` or `apiKeyHelper` via `--settings` instead |
| `ANTHROPIC_API_KEY` | API-key auth (alternative to OAuth) |
| `CLAUDE_CODE_SIMPLE=1` | Set by `--bare` mode; disables hooks, LSP, plugins |
| `CLAUDE_CODE_SAFE_MODE=1` | Set by `--safe-mode` |

## Scripting patterns

```sh
# One-shot query
claude -p "What ports are in use?"
echo "summarize this log" | claude -p

# Pipe file content
cat main.py | claude -p "Find bugs"

# Pipe diff for commit message
git diff | claude -p "Write a short commit message"

# Structured output
git diff | claude -p "List changed functions as JSON" --output-format json

# Custom agent with effort
claude -p "Review this code" --agent reviewer --effort xhigh --output-format json

# Auto-approve permissions (CI/unattended) — --permission-mode auto still runs a soft_deny/hard_deny
# classifier and can block/hang on flagged actions (git pushes, prod reads, etc.); use
# --dangerously-skip-permissions or --permission-mode bypassPermissions for guaranteed unattended runs
claude -p "Refactor this module" --dangerously-skip-permissions

# Background agent
claude --bg "Run tests every 30s and report failures"
claude agents --json

# Minimal mode for CI (no hooks, no LSP, no plugins)
claude --bare -p "Lint all files"

# With fallback model on overload (one-shot only)
claude -p "analyze" --fallback-model sonnet

# Custom system prompt
claude -p "Answer in Spanish" --system-prompt "Always reply in Spanish"

# Load additional settings
claude -p "Deploy" --settings ./deploy-settings.json
```
