---
name: opencode-task
description: Delegate a self-contained coding task to OpenCode CLI as an external subagent — `opencode-task` runs OpenCode's real bash/edit-capable `task` agent headlessly in a throwaway git worktree. Use when a self-contained coding task should run unattended outside Claude's own context/turn budget, in parallel, or exploratively without touching the current checkout, or when a second model's take on the same task is wanted; NOT for tasks needing Claude's own judgment mid-task, anything touching the current working tree directly (use Claude's own tools or the Agent tool instead), interactive human-driven OpenCode sessions (opencode-wt), or running under OpenCode itself (would mean OpenCode shelling out to itself).
---

Real agentic subagent wrapping the `opencode` CLI headlessly — a sibling of `llm`/`opencode-llm`, but with bash/edit/read tools, run unattended against a throwaway worktree.

- `opencode-task NAME "task description"` — runs OpenCode's `task` agent (bash/edit/read tools) headlessly against a throwaway worktree at `<repo>/.worktrees/NAME`, same convention `opencode-wt` uses. Re-running the same NAME resumes that worktree's session.
- `--auto` (unattended permission approval) is not a sandbox — global `opencode.json` denies `git push`/`git push *` for every OpenCode agent, the script never merges the worktree back, and the `task` agent denies `external_directory` so its edit/read/glob tools can't touch paths outside the worktree; its bash tool is NOT confined and can touch anything the OS user can. Treat it like any other subagent whose diff you must review before it matters: inspect with `opencode-git-wt NAME diff`, resume interactively with `opencode-wt NAME`, discard with `opencode-wt -d NAME`.
- Reuses a worktree by name (same name = same branch/session) — pick a fresh name per task; reusing one mid-flight races with any human `opencode-wt` session of the same name.
- `-m provider/model`, `--agent A` (default `task`), `-T secs` (default 1800) available. Exit 124 on timeout leaves the worktree in place for inspection, same as any other failure.
- When using `--agent` with a non-default agent (e.g. `reviewer`, `auditor`), verify the agent's `mode` is `all` or `primary` in its `.md` frontmatter — `mode: subagent` agents cannot be invoked via `opencode run --agent` and OpenCode silently falls back to `build` (full tools, no read-only enforcement). The script's pre-flight check catches this, but confirm with `opencode agent list` if you add custom agents.
- This is NOT a replacement for Claude's own Agent tool on in-repo work Claude can just do — reach for it when the task should run outside Claude's own turn/context (long-running, exploratory, or genuinely parallel to what Claude is doing), or when a second model's take on the same task is wanted.

## Fit
- **Good**: a self-contained coding subtask that benefits from running unattended/in parallel in its own worktree, or a second opinion from a different agent/model on the same problem.
- **Bad**: anything requiring Claude's own mid-task judgment or access to the current conversation's context; edits to the actual working tree Claude is already in (worktree isolation is the whole point — use Claude's own tools there); final authority on correctness/security for its output.
