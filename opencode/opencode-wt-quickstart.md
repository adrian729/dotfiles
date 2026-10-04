# `opencode-wt` + `opencode-git-wt` — quickstart

`opencode-wt` runs OpenCode sessions in separate git worktrees (`.worktrees/<name>`), each with a branch, saved conversation, and color. Worktrees separate working files but share git metadata and do not restrict shell access to other directories.

For standalone setup, run `bash opencode/standalone_quick_setup.sh` from the dotfiles repo. See the guide for Stow installation.

## Commands

```bash
opencode-wt <name> [color]    # start OR resume session <name>
opencode-wt -l                # list this repo's sessions (branch, color, clean/dirty)
opencode-wt -d <name>         # remove a worktree when you're done
opencode-wt -h                # help + valid colors
opencode-git-wt <name> <args> # run git in session worktree <name>
opencode-open-wt <editor> <name>  # open editor in session worktree <name>
```
Tmux: `prefix+w t` opens an fzf picker over worktrees — select, then choose claude or opencode.

The same command is both start and resume: the first run creates the worktree
+ branch + OpenCode session; running it again later continues that same
conversation. The color tints the tmux pane (or terminal background outside
tmux) — pass it once, it sticks to the name.

## The loop

1. **Start:** `cd your-repo && opencode-wt feature-auth blue` — worktree,
   branch, and tinted OpenCode session are created. Work in OpenCode; commits
   land on branch `feature-auth`.
2. **Stop:** after a successful exit on the original branch, unpushed commits trigger an offer to push and open/update a **draft PR** — Enter = yes, `n` = keep local. The worktree survives either way.
3. **Resume:** `opencode-wt feature-auth` — same worktree, same conversation,
   same color. Repeat 1–3 for review rounds.
4. **Finish (PR merged):** `opencode-wt -d feature-auth` — removes worktree;
   if `gh` sees its PR merged, it also offers to delete the branch.

Parallel work is multiple names: `opencode-wt bugfix-login red` in another
tmux pane runs independently.

## Checking a session from outside

```bash
opencode-git-wt feature-auth status --short    # what's dirty
opencode-git-wt feature-auth diff              # uncommitted edits
git log main..feature-auth                      # committed work — visible from main
code .worktrees/feature-auth                   # open the worktree in any editor
opencode-open-wt code feature-auth              # or use the open-wt helper
```

## Colors

`red` `maroon` `peach` `yellow` `green` `teal` `sky` `sapphire` `blue`
`lavender` `mauve` `pink` `flamingo` `rosewater`

Everything else (setup, lifecycle details, troubleshooting): `opencode-wt-guide.md`.
