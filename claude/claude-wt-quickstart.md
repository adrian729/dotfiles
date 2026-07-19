# `claude-wt` + `git-wt` — quickstart

`claude-wt` runs several Claude Code sessions on the same repo in
parallel, each in its own **git worktree**: an extra working folder of
the repo (`.worktrees/<name>`), on its own branch (`<name>`), so
sessions never touch each other's files — or your main checkout. One
name = one branch = one worktree = one Claude session = one color.

New machine? `./standalone_quick_setup.sh` tries to set everything up
automagically.

## Commands

```bash
claude-wt <name> [color]    # start OR resume session <name>
claude-wt -l                # list this repo's sessions (branch, color, clean/dirty)
claude-wt -d <name>         # remove a worktree when you're done
claude-wt -h                # help + valid colors
open-wt <editor> <name>     # open an editor in session worktree <name>
```

The same command is both start and resume: the first run creates the
worktree + branch + Claude session; running it again later continues
that same conversation. The color tints the tmux pane (or the terminal
background outside tmux) so you always know which session you're typing
into — pass it once, it sticks to the name.

## The loop

1. **Start:** `cd your-repo && claude-wt feature-auth blue` — worktree,
   branch, and tinted Claude session are created. Work in Claude as usual;
   commits land on branch `feature-auth`.
2. **Stop:** exit Claude. If the branch has unpushed commits, it offers to
   push and open/update a **draft PR** — Enter = yes, `n` = keep
   everything local. The worktree survives either way.
3. **Resume:** `claude-wt feature-auth` — same worktree, same
   conversation, same color. Repeat 1–3 for review rounds.
4. **Finish (PR merged):** `claude-wt -d feature-auth` — removes the
   worktree; if `gh` sees its PR merged, it also offers to delete the
   branch.

Parallel work is just multiple names: `claude-wt bugfix-login red` in
another tmux pane runs independently of `feature-auth`.

## Checking a session from outside

`git-wt <name> <git args...>` runs any git command *inside* that
session's worktree, from anywhere in the repo — it's shorthand for
`git -C .worktrees/<name> <git args...>`. Uncommitted changes
exist only in the worktree folder, so this is how you peek at them:

```bash
git-wt feature-auth status --short    # what's dirty in its worktree
git-wt feature-auth diff              # uncommitted edits
git log main..feature-auth            # committed work — visible from the main checkout
code .worktrees/feature-auth   # open the worktree in any editor
open-wt code feature-auth             # or use the open-wt helper
```

## Colors

`red` `maroon` `peach` `yellow` `green` `teal` `sky` `sapphire` `blue`
`lavender` `mauve` `pink` `flamingo` `rosewater`

Everything else (manual setup, lifecycle details, troubleshooting):
`claude-wt-guide.md`.
