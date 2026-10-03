---
name: claude-cli
description: Invoke Claude Code from another tool, script, or CI job; choose its working directory, tools, session, and output format. Use for CLI execution and troubleshooting, not for editing persistent Claude configuration.
---

# Claude CLI

## Workflow

1. Establish the task, working directory, required tools, and whether this is an independent run or a follow-up. A new process does not inherit the caller's conversation; supply the needed context and acceptance criteria.
2. Check `claude --help` or the relevant subcommand's help for unfamiliar options. Use the [CLI reference](https://code.claude.com/docs/en/cli-reference) for details omitted from help. Do not make an inference call merely to discover valid flags or agent names.
3. Run `claude -p` from the intended directory. Print mode can still use tools, edit files, and load that directory's configuration. Use a separate worktree when edits need an independent checkout; it does not inherit uncommitted changes automatically.
4. For unattended execution, allow the required operations through existing settings or scoped `--allowedTools` rules, and use `--permission-prompts none` so a remaining permission prompt becomes a denial rather than a wait. Report blocked operations; do not treat blanket permission bypass as a requirement for automation.
5. Check the process status and result, including reported errors or permission denials. Validate generated artifacts before integrating them. A successful process exit alone does not establish task completion.

## Invocation patterns

```sh
# Text supplied on stdin; disable built-in tools and configured MCP servers.
claude -p --tools "" --strict-mcp-config --mcp-config '{"mcpServers":{}}' \
  --permission-prompts none -- "Summarize the supplied log" < build.log

# Agentic task, run with the intended checkout as the shell working directory.
claude -p --output-format json --permission-prompts none -- "TASK"

# Follow up on a specific run.
claude -p --resume SESSION_ID --permission-prompts none -- "FOLLOW_UP"
```

- `--output-format json` returns a result envelope, not necessarily JSON authored by the model. Use `--json-schema` when the answer itself needs a schema. `--output-format stream-json --verbose` emits events; parse their types rather than concatenating all text.
- Capture the session ID for follow-ups. Avoid `--continue` in concurrent workflows because it chooses the most recent session. Use a fresh session for independent work; `--fork-session` retains the resumed conversation's context.
- Set `--model`, `--agent`, or `--effort` when the task or workflow calls for them. Check available custom agent definitions rather than assuming a fixed roster.
- Preserve normal configuration unless isolation or troubleshooting requires otherwise. `--bare` and `--safe-mode` disable different customizations; `--bare` also changes authentication sources.
