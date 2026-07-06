# `opencode-wt` — one command per parallel OpenCode session

One command that creates (or resumes) an OpenCode session in its own git
worktree — an extra working directory of the same repo, on its own branch —
with its own pane color. Run several sessions on one repo in parallel, with
zero cross-contamination.

```bash
opencode-wt <name> [color]      # start OR resume session <name>
opencode-wt -l                  # list this repo's session worktrees
opencode-wt -d <name>           # remove a worktree when done
opencode-wt -h                  # help + valid colors
opencode-git-wt <name> <args>   # run git in that session's worktree
opencode-open-wt <editor> <name>  # open editor in that session's worktree
```

## Setup (one-time)

Works on macOS and Linux. The scripts are plain bash — nothing to build.
In a hurry? `./standalone_quick_setup.sh` (ships in the same folder as this
guide) tries to do all of the below automagically.

### 1. Dependencies

- **git ≥ 2.31** (required) — `brew install git` / `sudo apt install git`.
- **OpenCode** (required) — https://opencode.ai — `npm install -g opencode-ai`
  or `brew install anomalyco/tap/opencode`. Run `opencode` once to log in.
- **gh, the GitHub CLI** (optional) — `brew install gh` / `sudo apt install gh`.
  `gh auth login` for draft-PR automation.
- **tmux** (optional) — pane tints and window renaming. Outside tmux the
  terminal background is tinted instead.

### 2. Install the scripts

```bash
cp opencode-wt opencode-git-wt opencode-open-wt ~/.local/bin/
chmod +x ~/.local/bin/opencode-wt ~/.local/bin/opencode-git-wt ~/.local/bin/opencode-open-wt
export PATH="$HOME/.local/bin:$PATH"  # add to ~/.zshrc or ~/.bashrc
```

Or via GNU Stow from the dotfiles repo: `stow opencode` places the scripts
in `~/.local/scripts/`.

### 3. Permissions

OpenCode needs `git push` denied so the wrapper handles pushing after the
session exits. Add to your global `~/.config/opencode/opencode.json`:

```json
{
  "permission": {
    "bash": {
      "*": "allow",
      "git push *": "deny"
    }
  }
}
```

## The 30-second mental model

One name = one branch = one worktree = one OpenCode session = one color.

```
my-repo/
├── .opencode/worktrees/
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

Two isolated sessions, each pane tinted with its color. The tint resets when
the session ends.

## Colors

`red` `maroon` `peach` `yellow` `green` `teal` `sky` `sapphire` `blue`
`lavender` `mauve` `pink` `flamingo` `rosewater`

Dark Catppuccin-Mocha-derived tints applied to the tmux pane background.
Outside tmux the terminal background is recolored instead (ghostty, kitty).

## Lifecycle (the PR loop)

- **Start:** `opencode-wt feature-auth blue` — fetches origin, creates
  worktree + branch + session, tints the pane. The session ID is captured
  after exit and saved to git config.
- **Stop:** exit OpenCode. If the branch has unpushed commits, offers to
  push and create/update a draft PR. The worktree survives.
- **Resume:** `opencode-wt feature-auth` — same worktree, same conversation
  (`opencode --session <saved-id>`), same color. Review rounds are just:
  resume → work → exit → Enter.
- **Crash recovery:** if the terminal closes before clean exit, next resume
  scans opencode's DB for any orphaned session matching the worktree
  directory and saves the mapping — no conversation lost.
- **Finish (PR merged):** `opencode-wt -d feature-auth` — removes worktree,
  deletes the orphaned session from opencode's DB, unset config, offers
  branch deletion if PR merged.

## Checking the work locally

```bash
opencode-git-wt feature-auth status --short   # what's dirty (incl. untracked)
opencode-git-wt feature-auth diff             # uncommitted edits
git log main..feature-auth                     # commits visible from main checkout
code .opencode/worktrees/feature-auth          # open in any editor
opencode-open-wt nvim feature-auth             # or use the helper
```

A worktree is not a copy — one `.git` with all branches and commits, two
windows into it. Commits are visible from your main checkout immediately.

## Niceties it handles for you

- `.opencode/worktrees/` is auto-added to `.git/info/exclude`.
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
sessions starting dev servers fight over ports, and isolation doesn't
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
