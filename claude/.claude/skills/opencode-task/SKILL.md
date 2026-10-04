---
name: opencode-task
description: Delegate a self-contained coding task or second opinion to OpenCode in a separate Git worktree. Use for unattended, independent, or parallel work with explicit context; not for recursive delegation from inside OpenCode.
---

# OpenCode Coding Delegation

`opencode-task` runs a real agent with shell, read, and edit tools in `<repo>/.worktrees/NAME`. It passes `--auto`, approving permissions that are not explicitly denied. The worktree separates checkouts; it does not sandbox bash or prevent external actions. The wrapper does not merge results into the caller's checkout.

## Workflow

1. **Specify the task.** Supply the scope, required context, acceptance criteria, and allowed external actions. The child does not inherit the caller's conversation. Use a fresh name for independent work; reuse a name only for a deliberate continuation with no other session using that worktree.
2. **Prepare the starting state.** For new work, create the worktree from the intended commit and transfer any required uncommitted or untracked content. For a continuation, inspect the existing worktree. Record the commit and pending changes before launching. The wrapper reuses an existing worktree unchanged. If it creates one instead, it fetches `origin`, reattaches an existing branch named `NAME`, or creates a branch from `origin/HEAD` when available, otherwise the main checkout's `HEAD`. It does not copy pending tracked edits; only matching untracked files from `.worktreeinclude` are copied into a newly created worktree.
3. **Select the model and agent.** Use a currently available free model unless explicitly asked to use a paid one, including by an invoked workflow. For free selection, compare `opencode-models free` with `opencode models opencode` and resolve stale entries. Pass the selected model with `-m` to make the choice explicit. Without it, the wrapper selects a configured free candidate present in the live catalog or fails; it does not use the ambient model. The default agent is `task`; for another agent, check `opencode agent list` for `primary` or `all` mode. Do not silently substitute an agent with different capabilities.
4. **Run and inspect completion.** Invoke `opencode-task NAME -m MODEL -- "TASK"` from the repository. Options follow `NAME`; `--agent AGENT` changes the agent and `-T SECS` sets the timeout (default 1800). Nonzero exits, including timeout 124, can leave partial edits. Inspect the worktree before retrying. Reusing its name resumes a session only when the wrapper previously saved its session ID.
5. **Review the complete result.** Check status, tracked changes against the recorded starting commit, new files, and any commits the agent made. Plain `git diff` misses staged files and commits. Validate the affected behavior, then integrate the reviewed changes as requested. Preserve useful work until integration or deliberate disposal is complete.

## Example

Run from the main checkout. Replace `NAME` and `START_SHA` with a fresh worktree name and the chosen commit hash; set `delegate_model` to the selected provider/model.

```sh
git worktree add -b NAME .worktrees/NAME START_SHA
# Transfer required pending changes here, if any, before launching.
opencode-task NAME -m "$delegate_model" -- "TASK, CONTEXT, AND ACCEPTANCE CRITERIA"

opencode-git-wt NAME status --short
opencode-git-wt NAME diff START_SHA --
opencode-git-wt NAME log --oneline START_SHA..HEAD
# Inspect untracked files separately; they are absent from git diff.
```

Use `opencode-wt NAME` for interactive follow-up. `opencode-wt -d NAME` can discard pending work; use it only when that work is safely integrated or intentionally abandoned, not as automatic failure cleanup.
