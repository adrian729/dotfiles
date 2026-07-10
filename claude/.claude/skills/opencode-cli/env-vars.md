## Environment variables — full reference

| Variable | Purpose |
|---|---|
| `OPENCODE_CONFIG` | Path to config file |
| `OPENCODE_CONFIG_DIR` | Path to config directory |
| `OPENCODE_CONFIG_CONTENT` | Inline JSON config (highest runtime override) |
| `OPENCODE_TUI_CONFIG` | Path to TUI config file |
| `OPENCODE_SERVER_PASSWORD` | Basic auth password for serve/web |
| `OPENCODE_SERVER_USERNAME` | Basic auth username (default: `opencode`) |
| `OPENCODE_PERMISSION` | Inline JSON permissions config |
| `OPENCODE_MODELS_URL` | Custom models config URL |
| `OPENCODE_DISABLE_CLAUDE_CODE` | Don't read `.claude` (prompt + skills) |
| `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS` | Don't load `.claude/skills` |
| `OPENCODE_DISABLE_AUTOUPDATE` | Disable update checks |
| `OPENCODE_DISABLE_PRUNE` | Disable old data pruning |
| `OPENCODE_DISABLE_LSP_DOWNLOAD` | Disable LSP auto-download |
| `OPENCODE_DISABLE_MOUSE` | Disable TUI mouse capture |
| `OPENCODE_DISABLE_DEFAULT_PLUGINS` | Disable default plugins |
| `OPENCODE_DISABLE_AUTOCOMPACT` | Disable context compaction |
| `OPENCODE_DISABLE_TERMINAL_TITLE` | Disable terminal title updates |
| `OPENCODE_ENABLE_EXPERIMENTAL_MODELS` | Enable experimental models |
| `OPENCODE_EXPERIMENTAL` | Enable all experimental features |
| `OPENCODE_EXPERIMENTAL_PLAN_MODE` | Enable plan mode |
| `OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS` | Enable background subagents |
| `OPENCODE_EXPERIMENTAL_SCOUT` | Enable Scout subagent |
| `OPENCODE_EXPERIMENTAL_PARALLEL` | Enable parallel web search |
| `OPENCODE_EXPERIMENTAL_LSP_TOOL` | Enable experimental LSP tool |
| `OPENCODE_EXPERIMENTAL_FILEWATCHER` | Enable file watcher |
| `OPENCODE_EXPERIMENTAL_BASH_DEFAULT_TIMEOUT_MS` | Default bash timeout |
| `OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX` | Max output tokens |
| `OPENCODE_AUTO_SHARE` | Automatically share sessions |
| `OPENCODE_FAKE_VCS` | Fake VCS provider (testing) |
