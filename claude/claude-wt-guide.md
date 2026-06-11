# `claude-wt` — one command per parallel Claude session

One command that creates (or resumes) a Claude Code session in its own git
worktree — an extra working directory of the same repo, on its own branch —
with its own pane color. Run several sessions on one repo in parallel, with
zero cross-contamination.

```bash
claude-wt <name> [color]    # start OR resume session <name>
claude-wt -l                # list this repo's session worktrees
claude-wt -d <name>         # remove a worktree when you're done
claude-wt -h                # help + valid colors
git-wt <name> <git args...> # run git in that session's worktree
```

## Setup (one-time)

Works on macOS and Linux. The script is plain bash — nothing to build.

### 1. Dependencies

- **git ≥ 2.31** (required) — check with `git --version`.
  macOS: `brew install git` (or the Xcode Command Line Tools).
  Linux: `sudo apt install git` / `sudo dnf install git`.
- **Claude Code** (required) — same installer on both OSes:

  ```bash
  curl -fsSL https://claude.ai/install.sh | bash
  ```

  Then run `claude` once to log in.
- **gh, the GitHub CLI** (optional) — powers the push + draft-PR
  automation. macOS: `brew install gh`. Linux:
  <https://github.com/cli/cli/blob/trunk/docs/install_linux.md>.
  Then authenticate with `gh auth login`.
- **tmux** (optional) — pane tints and window renaming.
  macOS: `brew install tmux`. Linux: `sudo apt install tmux` /
  `sudo dnf install tmux`. Outside tmux the terminal background is
  tinted instead (see Colors below).

### 2. Install the scripts

Put `claude-wt` and its companion `git-wt` somewhere on your PATH and make
them executable:

```bash
mkdir -p ~/.local/bin
cp claude-wt git-wt ~/.local/bin/
chmod +x ~/.local/bin/claude-wt ~/.local/bin/git-wt
command -v claude-wt git-wt   # should print both paths
```

If `command -v` prints nothing, add the directory to your PATH — in
`~/.zshrc` (macOS default shell) or `~/.bashrc` (most Linux distros):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Alternatively, via the dotfiles repo it ships in
([github.com/adrian729/dotfiles](https://github.com/adrian729/dotfiles)):
install GNU stow (`brew install stow` / `sudo apt install stow`), clone,
and run `./install.sh` — or `stow claude` for just this package. That
places the scripts in `~/.local/scripts/`, which is on PATH only if you
also use the repo's zsh config; otherwise add that directory to PATH as
above.

### 3. Smoke test

```bash
cd some-git-repo
claude-wt hello green        # creates worktree + branch + session, tints the pane
# exit Claude, then:
git-wt hello status --short  # peek at the worktree from outside
claude-wt -d hello           # remove the worktree (the branch survives -d)
git branch -D hello          # delete the branch too
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
which one you're typing into. The tint resets when the session ends (after
the push prompt, if any).

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

- **Uncommitted edits are the exception** — they exist only as files
  inside the worktree folder, so ask git *in there*. That's what `git-wt`
  is for: `git-wt <name> <args>` runs
  `git -C .claude/worktrees/<name> <args>` from anywhere in the repo.

  ```bash
  git-wt feature-auth status --short             # what's dirty (incl. untracked)
  git-wt feature-auth diff                       # uncommitted edits to tracked files
  git-wt feature-auth log --oneline main..HEAD   # its commits
  ```

  It also works as a git subcommand — `git wt feature-auth status` — which
  takes precedence over any `wt` alias you may have; help is `git wt -h`
  (not `--help`, which looks for a man page). Without the script: the
  `git -C` form above from the repo root, or `cd` in and use git normally.
  `claude-wt -l` shows a clean/dirty column per worktree.
- **Open it in your editor** — a worktree is a normal folder (its `.git`
  *file* points back at the shared repo), so open it as the project root
  and every git-aware tool just works:

  ```bash
  code .claude/worktrees/feature-auth          # VS Code, own window
  cd .claude/worktrees/feature-auth && nvim    # or any terminal editor
  ```

  VS Code's Source Control panel shows that branch's changes; for nvim,
  `cd` in first so cwd-based git plugins (gitsigns, fugitive) target the
  right tree. Editor and session share the working tree: your hand edits
  are visible to Claude on resume, and its edits appear in your editor
  live — handy for fixing something yourself mid-review.
- **Don't checkout the branch in your main folder** — git refuses while
  the worktree exists ("already used by worktree"), because a branch can
  only be checked out in one place. The worktree IS your local checkout of
  that branch: `cd` into it to run tests or commit by hand.
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
- **Push + draft PR on exit:** the wrapper handles the pushing — with
  your consent, after showing what would go up. PRs are created as drafts
  (`gh pr create --fill --draft`); mark them ready on GitHub.
- **Merged-PR cleanup:** `-d` checks the PR state via `gh` and offers to
  delete the local branch when it's merged (with `-D`, since squash-merged
  branches never look "fully merged" to git).
- If a `.worktreeinclude` file exists (gitignore syntax), matching
  untracked files (`.env`, local configs) are copied into new worktrees —
  same idea as `claude --worktree`'s.
- If branch `<name>` already exists (e.g. you removed the worktree but kept
  the branch), it's reattached instead of erroring.
- Inside tmux, sessions started with a color also get the window renamed
  to the session name (restored on exit).

PR automation needs the `gh` CLI, authenticated (`gh auth status`).
Without it you still get the push, plus the create-a-PR URL GitHub prints
in the push output.

## When to use which

- **`claude-wt <name>`** — tasks you'll come back to: named branch, resumable
  session, persistent color.
- **`claude --worktree <name>`** — throwaway experiments: Claude manages
  the worktree itself and offers to clean it up on exit.

Worktree caveats apply either way: each worktree needs its own dependency
install (`npm install`, `cargo build`, …); two sessions starting dev
servers will fight over the same port; and isolation doesn't prevent
normal merge conflicts when two sessions edit the same files — slice
tasks so they touch different areas.

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
- **`fatal: '<name>' is already used by worktree...`** (on git < 2.43:
  `...already checked out at...`): that branch is checked out elsewhere —
  pick another name or remove the other worktree.
- **Resume continued the wrong conversation:** session names that differ
  only in non-alphanumeric characters (`feat/x` vs `feat-x`) share a
  transcript folder — avoid running both at once.
- **Stale worktree state** (folder deleted by hand): the script runs
  `git worktree prune` before creating, so re-running usually self-heals.
