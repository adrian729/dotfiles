# `claude-wt` — one command per parallel Claude session

`worktree-guide.md` explains the worktree workflow in general. This guide is
about the shortcut that automates it: a single command that creates (or
resumes) a Claude Code session in its own worktree, on its own branch, with
its own pane color.

```bash
claude-wt <name> [color]    # start OR resume session <name>
claude-wt -l                # list this repo's session worktrees
claude-wt -d <name>         # remove a worktree when you're done
claude-wt -h                # help + valid colors
```

## The 30-second mental model

One name = one branch = one worktree = one Claude session = one color.

```
my-repo/                       ← main checkout
└── .claude/worktrees/
    ├── feature-auth/          ← claude-wt feature-auth blue
    └── bugfix-login/          ← claude-wt bugfix-login red
```

The same command is both "start" and "resume": if the worktree doesn't exist
it's created (branch `<name>`, from `origin/HEAD`, falling back to local
`HEAD`); if it does, your previous Claude conversation in it is continued.
The color sticks to the name — pass it once, it's reapplied on every resume.

## Quickstart

```bash
# tmux pane 1
cd my-repo && claude-wt feature-auth blue

# tmux pane 2
cd my-repo && claude-wt bugfix-login red
```

Two isolated sessions, each pane tinted with its color so you always know
which one you're typing into. The tint resets when Claude exits.

## Colors

`red` `maroon` `peach` `yellow` `green` `teal` `sky` `sapphire` `blue`
`lavender` `mauve` `pink` `flamingo` `rosewater`

Dark Catppuccin-Mocha-derived tints applied to the tmux pane background.
Neighbors in that list look similar at this subtle tint level (sky vs
sapphire, pink vs flamingo) — for sessions running side by side, pick
names far apart in the list.

Tints are applied with `tmux select-pane -P`, so the theme can't override
them and text stays readable. Outside tmux, the terminal background is
recolored instead (works in ghostty and kitty) and restored on exit.

## Lifecycle (the PR loop)

- **Start:** `claude-wt feature-auth blue` — fetches origin, creates
  worktree + branch (from the latest remote default branch) + named
  session, tints the pane.
- **Stop:** just exit Claude (or detach tmux). If the branch has unpushed
  commits, the script shows them (commit list, diff stats, what stays
  uncommitted) and asks:

  ```
  Session 'feature-auth' has 2 unpushed commit(s):
    abc1234 add login form
    def5678 wire auth API
  8 files changed, 240 insertions(+), 12 deletions(-)
  Push and open/update draft PR? [Y/n]
  ```

  Enter = pushed and the draft PR is created (or updated, if it already
  exists). `n` = everything stays local. Either way the worktree survives —
  no keep/delete prompts, unlike `claude --worktree`.
- **Resume:** `claude-wt feature-auth` — same worktree, same conversation
  (`claude --continue` scoped to that folder), same color, no extra args.
  Review rounds are just: resume → work → exit → Enter.
- **Finish (after the PR merges on GitHub):** `claude-wt -d feature-auth` —
  removes the worktree, detects the merged PR via `gh`, and offers to
  delete the local branch too. Then `git pull` in the main checkout to
  catch main up. Uncommitted changes always make `-d` ask before
  discarding.

## Checking the work locally

The part that's easy to get wrong: a worktree is not a copy. There is
**one** repository — one `.git` with all branches and commits — and two
windows into it. The moment the session commits, that commit is visible
from your main checkout. Nothing to sync, pull, or push between them.

- **Inspect from the main checkout** without going anywhere:

  ```bash
  git log main..feature-auth     # commits the session made
  git diff main...feature-auth   # its full committed diff
  ```

  Uncommitted edits are the exception — they exist only as files inside
  the worktree folder (`cd .claude/worktrees/feature-auth && git status`).
- **Don't checkout the branch in your main folder** — git refuses while
  the worktree exists ("already used by worktree"), because a branch can
  only be checked out in one place. The worktree IS your local checkout of
  that branch: `cd` into it to run tests, open nvim, or commit by hand.
  If you ever do want it in the main folder, `claude-wt -d <name>` first
  (the branch survives), then `git checkout <name>` works.
- **Parallel PRs are independent:** each worktree/branch/PR knows nothing
  about the others. Your main checkout's own uncommitted work is never
  touched by any of it.

## Niceties it handles for you

- `.claude/worktrees/` is auto-added to `.git/info/exclude`, so worktrees
  never show up as untracked files — no per-repo `.gitignore` edit needed.
- **Fetch on create:** new branches start from the latest remote default
  branch, not a stale snapshot (offline → warning, last-known state is
  used). Resume never fetches, so it stays instant.
- **Push + draft PR on exit:** Claude sessions are denied `git push` by
  settings.json on purpose — the wrapper does the pushing, with your
  consent, after showing what would go up. PRs are created as drafts
  (`gh pr create --fill --draft`); mark them ready on GitHub.
- **Merged-PR cleanup:** `-d` checks the PR state via `gh` and offers to
  delete the local branch when it's merged (with `-D`, since squash-merged
  branches never look "fully merged" to git).
- If a `.worktreeinclude` file exists (gitignore syntax), matching
  gitignored files (`.env`, local configs) are copied into new worktrees,
  same as `claude --worktree` does.
- If branch `<name>` already exists (e.g. you removed the worktree but kept
  the branch), it's reattached instead of erroring.
- Inside tmux the window is also renamed to the session name.

PR automation needs the `gh` CLI, authenticated (`gh auth status`).
Without it you still get the push, plus the create-a-PR URL GitHub prints
in the push output.

## When to use which

- **`claude-wt <name>`** — tasks you'll come back to: named branch, resumable
  session, persistent color.
- **`claude --worktree <name>`** — throwaway experiments: Claude cleans up
  after itself on exit (see `worktree-guide.md`).

All caveats from `worktree-guide.md` still apply: per-worktree dependency
installs, dev-server port conflicts, and merge conflicts if two sessions
edit the same files.

## Troubleshooting

- **"could not create the PR via gh":** check `gh auth status` — the push
  itself succeeded, so the PR-creation URL from the push output still
  works as a fallback.
- **No color appears:** you're probably outside tmux in a terminal that
  ignores OSC 11 — or you never passed a color for this name (`claude-wt -l`
  shows what's saved).
- **Resume opened a fresh session:** the conversation transcript for that
  folder is gone (e.g. cleaned `~/.claude/projects/`). The worktree and
  branch are untouched; just keep working.
- **`fatal: '<name>' is already used by worktree...`:** that branch is
  checked out elsewhere — pick another name or remove the other worktree.
- **Stale worktree state** (folder deleted by hand): the script runs
  `git worktree prune` before creating, so re-running usually self-heals.
