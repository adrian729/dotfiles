# `opencode-wt` — one command per parallel OpenCode session

Creates or resumes an OpenCode session in a named git worktree with its own branch and pane color. Worktrees separate working files but share git metadata; they do not restrict shell access to other checkouts.

```bash
opencode-wt <name> [color]      # start OR resume session <name>
opencode-wt -l                  # list this repo's session worktrees
opencode-wt -d <name>           # remove a worktree when done
opencode-wt -h                  # help + valid colors
opencode-git-wt <name> <args>   # run git in that session's worktree
opencode-open-wt <editor> <name>  # open editor in that session's worktree
```
Tmux: `prefix+w t` opens an fzf picker over worktrees — select one, then choose claude or opencode at the prompt (`prefix+w w` for stock choose-tree).

## Setup (one-time)

Works on macOS and Linux. The scripts use Bash. `standalone_quick_setup.sh`, next to this guide, installs the worktree helpers and their dependencies.

### 1. Dependencies

- **jq** (required) — parses the OpenCode session list.
- **git** (required) — `brew install git` / `sudo apt install git`.
- **OpenCode** (required) — https://opencode.ai — `npm install -g opencode-ai`
  or `brew install anomalyco/tap/opencode`. Run `opencode` once to log in.
- **gh, the GitHub CLI** (optional) — `brew install gh` / `sudo apt install gh`.
  `gh auth login` for draft-PR automation.
- **fzf** (optional) — powers `wt-sessionizer`'s picker (bound to `prefix+w t` in tmux).
  `brew install fzf` / `sudo apt install fzf`.
- **tmux** (optional) — pane tints and window renaming. Outside tmux the
  terminal background is tinted instead.

### 2. Install the scripts

```bash
# From the dotfiles repo:
bash opencode/standalone_quick_setup.sh
. "$HOME/.local/.local_profile"
```

Standalone setup backs up differing local scripts and writes PATH additions to `~/.local/.local_profile`. The dotfiles shell loads this file; other shell setups need to source it.

For the complete configuration, run root `install.sh` and select `agents` and `opencode`. A manual Stow install from the repo root must use `stow --no-folding --target="$HOME" agents opencode`, followed by `bash opencode/install.sh` to copy settings and resolve model pins. If standalone script copies already exist, run `bash opencode/pre_stow.sh` before stowing.

### 3. Permissions

The wrapper leaves OpenCode permissions to your configuration. After a successful session exit on the original branch, it can offer to push and open/update a draft PR with your consent.

## The 30-second mental model

One name = one branch = one worktree = one OpenCode session = one color.

```
my-repo/
├── .worktrees/
│   ├── feature-auth/          ← opencode-wt feature-auth blue
│   └── bugfix-login/          ← opencode-wt bugfix-login red
└── (main checkout)
```

The same command is both "start" and "resume": if the worktree doesn't exist
it's created (branch `<name>`, from `origin/HEAD`); if it does, your previous
OpenCode conversation is resumed. The color sticks to the name.

## Quickstart

```bash
# tmux pane 1
cd my-repo && opencode-wt feature-auth blue

# tmux pane 2
cd my-repo && opencode-wt bugfix-login red
```

`prefix+w t` in tmux opens a picker over all worktrees — select one, then
choose claude or opencode at the follow-up prompt.

Two sessions in separate working directories, each pane tinted with its color. The tint resets when the session ends.

## Colors

`red` `maroon` `peach` `yellow` `green` `teal` `sky` `sapphire` `blue`
`lavender` `mauve` `pink` `flamingo` `rosewater`

Dark Catppuccin-Mocha-derived tints applied to the tmux pane background.
Outside tmux the terminal background is recolored instead (ghostty, kitty).

## Lifecycle (the PR loop)

- **Start:** `opencode-wt feature-auth blue` — fetches origin, creates
  worktree + branch + session, tints the pane. The session ID is captured
  after exit and saved to git config.
- **Stop:** after a successful exit on the original branch, offers to push unpushed commits and create/update a draft PR. Failed sessions retain their exit status and worktree without offering a push.
- **Resume:** `opencode-wt feature-auth` — same worktree, same conversation
  (`opencode --session <saved-id>`), same color. Review rounds are just:
  resume → work → exit → Enter.
- **Crash recovery:** if the saved session ID is missing, the next start looks for the latest top-level session matching the worktree directory. This is best-effort recovery; inspect OpenCode history if it chooses the wrong conversation.
- **Finish (PR merged):** `opencode-wt -d feature-auth` — removes worktree,
  deletes the orphaned session from opencode's DB, unset config, offers
  branch deletion if PR merged.

## Checking the work locally

```bash
opencode-git-wt feature-auth status --short   # what's dirty (incl. untracked)
opencode-git-wt feature-auth diff             # uncommitted edits
git log main..feature-auth                     # commits visible from main checkout
code .worktrees/feature-auth                   # open in any editor
opencode-open-wt nvim feature-auth             # or use the helper
```

A worktree is not a copy — one `.git` with all branches and commits, two
windows into it. Commits are visible from your main checkout immediately.

## Niceties it handles for you

- `.worktrees/` is auto-added to `.git/info/exclude`.
- **Fetch on create:** new branches start from the latest remote default
  branch. Resume never fetches.
- **Push + draft PR on exit:** with your consent, after showing what would
  go up.
- **Merged-PR cleanup:** `-d` checks PR state via `gh` and offers to delete.
- **Crash-resistant session tracking:** session ID captured after exit,
  recovered on next start if missing.
- `-d` cleans up the orphaned session from opencode's DB.
- If a `.worktreeinclude` file exists, matching untracked files are copied.
- If branch `<name>` already exists, it's reattached instead of erroring.

## When to use which

- **`opencode-wt <name>`** — tasks you'll come back to: named branch,
  resumable session, persistent color.
- **Raw `opencode`** — throwaway experiments, no worktree needed.

Worktree caveats apply: each worktree needs its own `npm install`, two
sessions starting dev servers can compete for ports, and separate checkouts do not
prevent merge conflicts when two sessions edit the same files.

## Troubleshooting

- **"could not create the PR via gh":** check `gh auth status` — the push
  succeeded, use the URL from the push output.
- **No color appears:** outside tmux in a terminal that ignores OSC 11, or
  no color saved for this name.
- **`fatal: '<name>' is already used by worktree`:** that branch is checked
  out elsewhere — pick another name or remove the other worktree.
- **Resume opened a fresh session:** the session ID mapping was lost (e.g.
  `git config` cleared). The worktree and branch are fine — just keep
  working.
