# Parallel Claude Code sessions with git worktrees

Run several Claude Code sessions on the same repo at once — each in its own
folder, on its own branch, with zero cross-contamination.

## The 30-second mental model

A git worktree is an extra working directory for a repo you already have:
same `.git`, different folder, different branch. Claude Code manages them
for you via `claude --worktree`.

```
my-repo/                  ← main checkout (branch: main)
└── .claude/worktrees/
    ├── feature-auth/     ← session 1 (branch: worktree-feature-auth)
    └── bugfix-login/     ← session 2 (branch: worktree-bugfix-login)
```

## Quickstart (zero setup)

```bash
# Terminal 1
cd my-repo && claude --worktree feature-auth

# Terminal 2
cd my-repo && claude --worktree bugfix-login
```

First time in a repo: run plain `claude` once and accept the trust dialog —
`--worktree` refuses to start before that.

Each session gets its own folder and branch (`worktree-<name>`), branched
from the remote's default branch (usually `main`). Name worktrees after
tasks and attribution reads itself — every session's commits land on its
own branch:

```bash
git log main..worktree-feature-auth    # what did this session do?
git diff main...worktree-feature-auth  # what did it change?
```

Uncommitted edits are attributable only by which folder they sit in —
commit early.

## Session lifecycle

- **During:** work normally; sessions can't touch each other's files.
- **On exit:** no changes → worktree and branch are auto-deleted (unless
  you named the session — then Claude asks); changes → Claude asks whether
  to keep or delete.
- **Resume later:** run `claude --resume` from the repo — the picker shows
  the current worktree's sessions; press `Ctrl+W` to widen to all worktrees
  of the repo.
- **Merge back:** `git push -u origin worktree-feature-auth` and open a
  PR — or from the main checkout: `git merge worktree-feature-auth`.
- **Manual cleanup if ever needed:** `git worktree list`,
  `git worktree remove <path>`, `git worktree prune`.

## One-time per-repo config (optional but recommended)

- **`.worktreeinclude`** at the repo root (gitignore syntax): gitignored
  files to copy into each new worktree, e.g. `.env`. Without it, worktrees
  start without your untracked secrets/configs.
- **`"worktree": {"baseRef": "head"}`** in the repo's
  `.claude/settings.json` only if you want new worktrees branched from
  whatever you currently have checked out, instead of the remote's default
  branch.
- **Add `.claude/worktrees/` to the repo's `.gitignore`** so worktree
  folders don't show up as untracked files in the main checkout.

## Caveats (the honest list)

- **Dependencies aren't shared:** each worktree needs its own
  `npm install` / `pip install` / build. Isolation is the point — this is
  the cost.
- **Port conflicts:** two sessions starting dev servers will fight over
  the same port; vary the port per session or run only one server.
- **Isolation ≠ conflict-free merges:** worktrees prevent conflicts *while
  working*, but two sessions editing the same files still produce normal
  merge conflicts when both branches merge. Slice tasks so sessions touch
  different areas.
- **One session per worktree:** never open the same *session* in two
  terminals (messages interleave into one transcript). Different worktrees
  = different sessions, which is the whole pattern.
- **Same branch in two worktrees is impossible** — git refuses, which
  protects you.

## Manual alternative (full control)

To name and place things yourself:

```bash
git worktree add ../my-repo-feature -b feature/x
cd ../my-repo-feature && claude
```

Same isolation, no auto-cleanup — remove with `git worktree remove` when done.

## Bonus tips

- Name sessions (`claude -n <name>` or `/rename`) so the resume picker
  stays legible.
- Plan mode (Shift+Tab) before big changes; one task per session rather
  than one mega-session.

Docs: https://code.claude.com/docs/en/worktrees
