---
name: opencode-cli
description: Invoke or inspect OpenCode from a shell, script, or another agent. Use for direct CLI runs, sessions, server attachment, and troubleshooting; use opencode-task for the dotfiles worktree workflow or opencode-llm for its text relay.
---

# OpenCode CLI

## Workflow

1. Choose the working directory, agent, model, and session. Supply the task and necessary context explicitly; a separate process does not inherit the caller's conversation. Do not launch recursive OpenCode delegation from inside OpenCode; diagnostic commands remain useful there.
2. Check `opencode run --help` or the relevant subcommand's help for installed options. Use the [CLI reference](https://opencode.ai/docs/cli/) for additional commands and environment variables.
3. For delegation, use a currently available free model unless explicitly asked to use a paid one, including by an invoked workflow. For free selection, compare `opencode-models free` with `opencode models opencode`; resolve stale catalog entries before relying on them. Pass the selected model with `-m` rather than assuming an agent has a valid pin.
4. Check `opencode agent list` for the intended agent. Direct `run --agent` calls need a `primary` or `all` agent; do not rely on a subagent-only definition to constrain the run. The dotfiles `task` agent can edit and run shell commands; `relay` is intended for supplied-text responses.
5. Run with `--format json` when a script needs structured events. Check exit status, error events, and actual task results before accepting the response. Retain the session ID when follow-up work is needed.

```sh
# Set delegate_model to the selected provider/model; replace other placeholders.
opencode run -m "$delegate_model" --agent task --dir /path/to/worktree \
  --format json -- "TASK"

opencode run -m "$delegate_model" --agent task --dir /path/to/worktree \
  --session SESSION_ID --format json -- "FOLLOW_UP"

opencode session list --format json
```

## Execution details

- `--dir` selects the working directory; it is not a shell sandbox. `external_directory` permissions do not confine bash commands.
- For an authorized unattended run, `--auto` approves permissions that are not explicitly denied. Choose permissions and workspace to match the task; the flag adds neither filesystem isolation nor a read-only guarantee.
- JSON output is an event stream. Extract text events, keeping the latest text per `part.id` when snapshots repeat; inspect error events separately.
- Use `--session ID` for deliberate follow-ups. `--continue` selects the last session; `--fork` retains that session's context and is not an independent candidate.
- `--attach URL` uses an existing server; its `--dir` path belongs to that server's filesystem. Inspect effective configuration with `opencode debug config` when behavior differs from local files.
