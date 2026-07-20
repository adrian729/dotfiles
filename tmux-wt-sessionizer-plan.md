# Tmux Worktree Sessionizer — plan

## Design decisions (confirmed with user)

- 2 tmux keymaps, one per tool (claude, opencode) — no tool-selection prompt.
- Each opens an fzf list of the *current repo's* existing `.worktrees/<name>` entries (repo-scoped, resolved from the pane's cwd — same scope as `claude-wt -l`/`opencode-wt -l`).
- Enter on a row -> open that worktree with the bound tool.
- A third fzf keybinding (`ctrl-n`) -> create new, using whatever was typed in the fzf query box as the name. Validated against the branch-naming rule and against "already exists"; on failure, shows an inline error and redisplays the same list (loop, not exit) — no modal, no permission prompt.
- Opening/creating lands in a new tmux window in the current session (not a new session) — the sessionizer script itself runs inside a `tmux neww` window and then `exec`s directly into the chosen tool, so it never leaves this window/session in the first place. This is unrelated to `tmux-sessionizer`'s `prefix+f` behavior, which switches the client to a different (possibly new) session for the matched path, and unrelated to the `C-o`/`C-c` popup bindings' `popup -E` mechanism (an overlay, not a window).
- Two guard clauses run before the picker loop, in order: (1) `command -v fzf` — without fzf installed, the picker can never start, so this fails fast with a clear message rather than confusingly falling through to fzf's own missing-binary error inside the loop; (2) a git-repository check, using the same `git rev-parse --path-format=absolute --git-common-dir` call `claude-wt`'s own `main_root` uses (not `--show-toplevel`, which fails inside a bare repo or a cwd nested under `.git` where `--git-common-dir` still succeeds) — without this, the loop's very first `listing=$(claude-wt -l)` would fail (`claude-wt`'s own `main_root` calls `die "not inside a git repository"` and exits non-zero), and under `set -e` a failing command substitution in a plain assignment aborts the script right there. That's not a broken outcome in itself, but `claude-wt`'s message prints with no pause, so in a `neww` window it flashes and vanishes before it can be read; the explicit guard replaces it with the sessionizer's own message plus a brief `sleep`, so the reason is actually readable before the window closes. Both guards print a clear message and `sleep` briefly before exiting. `opencode-wt-sessionizer` inherits both guards byte-identically (same logic, `claude-wt` -> `opencode-wt` substitution).
- Accepted risk, not fixed: the `ctrl-n` "already exists" pre-check and the real `git worktree add` inside `claude-wt`/`opencode-wt` aren't atomic. Two panes racing to create the same brand-new name can both pass the sessionizer's pre-check before either finishes creating it; the loser hits `claude-wt`'s own raw git error instead of the sessionizer's friendlier message. Separately, a leftover non-worktree `.worktrees/<name>` directory (e.g. an empty parent left behind by a prior slashed-name cleanup) is invisible to the pre-check and would hit the same kind of `cmd_start` failure via `exec`, with no loop/redisplay left to catch it since `exec` has already replaced the sessionizer process. Both are pre-existing gaps in `claude-wt`/`opencode-wt`'s own lack of locking, not something this feature closes — doing so would need a retry-and-redisplay wrapper around `exec`, which is real added machinery against a design that's deliberately a thin wrapper with no shared lib. Left as-is, consistent with this repo's "don't build for hypothetical needs" convention.

## New files

- `claude/.local/scripts/claude-wt-sessionizer`
- `opencode/.local/scripts/opencode-wt-sessionizer`

Both must be created executable (`chmod +x`), matching the git mode `100755` that `claude-wt`/`opencode-wt` are already tracked at — a non-executable script fails instantly with the shell's own bare "permission denied" and no deliberate pause, unlike the guarded failure modes below (missing fzf, outside a git repo), which print a message and sleep briefly so it's readable before the window closes. This is the one failure mode with zero on-screen feedback, so it's worth ruling out first if a window ever flashes and closes with nothing readable in it.

Same duplication convention as `claude-wt`/`opencode-wt` themselves (no shared lib between packages). Each is a thin wrapper, not a rewrite of the listing/creation logic:

```bash
#!/usr/bin/env bash
# claude-wt-sessionizer — fzf picker over claude-wt's worktrees; ctrl-n creates a new one.
set -euo pipefail

command -v fzf >/dev/null 2>&1 || {
  echo "claude-wt-sessionizer: fzf is required (brew install fzf / apt install fzf)" >&2
  sleep 2
  exit 1
}

git rev-parse --path-format=absolute --git-common-dir >/dev/null 2>&1 || {
  echo "claude-wt-sessionizer: not inside a git repository" >&2
  sleep 2
  exit 1
}

query=""
while true; do
  listing=$(claude-wt -l)
  rows=$(awk 'NR>1' <<<"$listing")
  names=$(awk 'NR>1{print $1}' <<<"$listing")

  if result=$(fzf --print-query --expect=ctrl-n --query="$query" \
      --header='enter: open   ctrl-n: create new (type name above)' <<<"$rows"); then
    rc=0
  else
    rc=$?
  fi
  # 130 = Esc/Ctrl-C abort: leave the picker, keyed on fzf's documented exit
  # code rather than on whatever it left in the query line.
  [ "$rc" -eq 130 ] && exit 0
  query=$(sed -n 1p <<<"$result")
  key=$(sed -n 2p <<<"$result")
  sel=$(sed -n 3p <<<"$result")

  case "$key" in
    ctrl-n)
      name=$query
      if ! git check-ref-format --branch "$name" >/dev/null 2>&1; then
        echo "claude-wt-sessionizer: '$name' is not a valid worktree/branch name" >&2
        sleep 1.5; continue
      fi
      if grep -qxF "$name" <<<"$names"; then
        echo "claude-wt-sessionizer: '$name' already exists — select it from the list" >&2
        sleep 1.5; continue
      fi
      exec claude-wt "$name"
      ;;
    *)
      if [ -n "$sel" ]; then
        exec claude-wt "$(awk '{print $1}' <<<"$sel")"
      elif [ -n "$query" ]; then
        echo "claude-wt-sessionizer: no match — press ctrl-n to create '$query'" >&2
        sleep 1.5; continue
      else
        exit 0
      fi
      ;;
  esac
done
```

Both guard clauses (fzf presence, then git-repository check) run before the picker loop and exit with a clear message plus a short pause if either fails — see the Design decisions bullets above for why each one exists and why the git-repo check uses `--git-common-dir` rather than `--show-toplevel`.

Capturing fzf's exit status via the `if result=$(fzf …); then rc=0; else rc=$?; fi` form (rather than a bare `result=$(fzf …) || true`) matters because fzf exits non-zero for cases that happen before any `case "$key"` logic can run — 130 for an Esc/Ctrl-C abort, and 1 for "no match" (Enter pressed with nothing selected, or `ctrl-n` pressed against a query that fuzzy-matches nothing in the list). A bare `result=$(fzf …)` under `set -e` would abort the script at that assignment on any non-zero exit; the `if`/`else` form both neutralizes `set -e` there (the assignment is the condition of an `if`, so it's exempt) and preserves the real exit code in `rc`. The explicit `[ "$rc" -eq 130 ] && exit 0` then treats abort as a clean exit deterministically, keyed on the exit status fzf documents for Esc/Ctrl-C (130) — deliberately *not* on whether `--print-query` echoes the typed query on the abort path. That output-on-abort behavior is undocumented and not something to depend on; keying off exit 130 sidesteps it entirely, so a query that was typed and then aborted can never strand the loop in the "no match — press ctrl-n" branch (which is the failure the earlier `|| true`-plus-empty-query design was exposed to if fzf ever *did* print the query on abort). Exit 1 (no match) deliberately falls through instead of exiting: `query` still holds the typed text via `--print-query`'s first line, so the `*)` arm's `elif [ -n "$query" ]` shows the "press ctrl-n to create" hint and redisplays. The `[ "$rc" -eq 130 ] && exit 0` line is itself `set -e`-safe: a false `[ … ]` on the left of `&&` short-circuits without triggering an exit — the same `[ … ] && …` idiom `claude-wt` already relies on under `set -euo pipefail` (e.g. `[ -n "$tint" ] && trap reset_color EXIT`).

The loop fetches `claude-wt -l` once per iteration into `$listing`, deriving both the fzf input (`$rows`) and the existence-check list (`$names`) from that single call rather than invoking `claude-wt -l` twice. Feeding `grep -qxF "$name" <<<"$names"` from a variable rather than a live pipe also avoids a separate, purely theoretical hazard: under `pipefail`, a `grep -q` that matches and exits early can `SIGPIPE` an upstream pipe-fed producer, and the pipeline's reported exit status could then be the producer's `SIGPIPE` death instead of grep's real match — a here-string has no producer process to signal, so this can't happen. `--query="$query"` on the `fzf` invocation means a failed `ctrl-n` attempt (bad name, or "already exists") redisplays the list with what was typed still in the query box, so the user corrects it in place instead of retyping from scratch.

With Esc/Ctrl-C already handled upfront by the `[ "$rc" -eq 130 ] && exit 0` check, the `case "$key" in ... esac` block only has to tell apart the *accept* paths, all of which exit fzf with 0 (a highlighted row) or 1 (no match): `ctrl-n` (its own arm, since `--expect` names it, populating `$key`); a plain-Enter or mouse-double-click accept (empty `$key` — `--expect` only fires for keys it names — but `$sel` populated with the highlighted row); and a plain-Enter with no match (empty `$key`, empty `$sel`). The `*)` arm disambiguates the latter two by inspecting `$sel`/`$query` directly rather than by key identity, so real Enter and mouse double-click land in the same branch and open the selected row identically, while an empty-selection Enter either offers the ctrl-n hint (`$query` non-empty) or exits cleanly (`$query` empty). `ctrl-n` is the only key whose identity actually matters, so `--expect` only needs to list it.

`--expect=ctrl-n` is also safe against this repo's own fzf config: `zsh/.config/zsh/fzf.zsh` keeps its interactive UI options (which include a `--bind='ctrl-n:down,ctrl-p:up'`) in a non-exported `_FZF_UI_OPTS` var precisely so they never leak into non-interactive `neww`/popup fzf calls via the tmux server env, and it deliberately does not export `FZF_DEFAULT_OPTS` at all. So nothing rebinds `ctrl-n` to `down` underneath the sessionizer. Even if some environment did export such a bind, command-line `--expect=ctrl-n` is applied after `FZF_DEFAULT_OPTS` and takes precedence, so `ctrl-n` would still resolve as the accept-key rather than a cursor move.

`opencode-wt-sessionizer` is byte-identical except `claude-wt` -> `opencode-wt` throughout (including the same fzf-presence and git-repo guards, the same `if result=$(fzf …); then rc=0; else rc=$?; fi` exit-code capture with its `[ "$rc" -eq 130 ] && exit 0` abort check, the same `listing`/`rows`/`names` caching, and the same `case` block). Reuses `claude-wt -l`/`opencode-wt -l` for listing rather than re-parsing `git worktree list --porcelain` — both already print the same shared `.worktrees/` table (from the earlier unification work), so either script's `-l` sees worktrees regardless of which tool created them. Window/pane naming and color tint are inherited for free: `claude-wt`'s own `apply_color()` renames the tmux window to `$name` only when a color is set for that name (see Verification below for what to expect on a colorless create). No color prompt on create — kept out of scope; color can be set after the fact by re-running `claude-wt <name> <color>`.

## tmux.conf changes (`tmux/.config/tmux/tmux.conf`)

Add a mnemonic 2-key table using tmux's custom-key-table mechanism (`switch-client -T <table>` to enter it, `bind -T <table> ...` for its own bindings) — a different activation path than this file's existing `-T copy-mode-vi` table (which tmux enters automatically on copy-mode, not via an explicit `switch-client -T` binding), but the same underlying `bind -T <table>` syntax that file's own `copy-mode-vi` rebinds already use:

```
bind W switch-client -T wt
bind -T wt c neww -c "#{pane_current_path}" ~/.local/scripts/claude-wt-sessionizer
bind -T wt o neww -c "#{pane_current_path}" ~/.local/scripts/opencode-wt-sessionizer
```

`-c "#{pane_current_path}"` on the `neww` invocation is required, not cosmetic: without it, `neww` runs in the tmux *session's* start directory, not the active *pane's* cwd — and this whole design is cwd-dependent (the git-repo guard above, and `claude-wt -l`'s own repo-root resolution, both read the process's cwd). Omitting `-c` would mean pressing `prefix+W c` from a pane you've `cd`'d into a repo could either hit the "not inside a git repository" guard (if the session's start dir isn't a repo) or silently operate on the wrong repo (if the session's start dir is a *different* git repo). This repo's own tmux.conf already relies on the same flag for the same reason on every other window/pane-spawning binding (`bind c new-window -c "#{pane_current_path}"`, both `split-window` bindings, `-d "#{pane_current_path}"` on the `C-o`/`C-c` popups) — those flags would be redundant if `new-window`/`neww`/`popup` inherited the pane's path by default, which they don't.

Binding `-T wt c`/`-T wt o` directly to `neww` — rather than routing through an intermediate `run-shell "tmux neww ..."` string, as an earlier draft of this plan did — avoids a shell-re-parse hazard entirely. tmux performs format-expansion of `#{pane_current_path}` into the literal path the same way in both forms, but *where* that expansion lands differs: bound directly (as here), the expanded path is handed straight to `neww` as an already-tokenized argument — no shell layer ever sees it, so there's nothing to re-parse and no quote character in the path can cause trouble. Routed through `run-shell "tmux neww -c '#{pane_current_path}' ..."`, the same expansion happens *before* the shell re-parses that argument string, so the expanded path is substituted as literal text inside the single quotes; a path containing an apostrophe (e.g. a worktree checked out under a directory named "Client's Files") closes the quote early, `run-shell` fails to parse its argument (exit 2), and the whole thing silently does nothing — no window, no visible error, because fzf/tmux give no feedback path for a `run-shell` parse failure. Binding directly to `neww` sidesteps the problem rather than working around it: this is exactly the pattern this same file already uses for `bind c new-window -c "#{pane_current_path}"` and both `split-window -c "#{pane_current_path}"` bindings — `-c` there is a direct argument to a bound command, not a fragment of a shell command string, so no shell re-parse is involved and no quoting scheme for the format string is needed at all.

Lowercase `prefix+w` is tmux's stock `choose-tree -Zw` and is live in this config (confirmed via `tmux list-keys -T prefix` against a real detached server started with this repo's `tmux.conf` — nothing here rebinds it, so the stock default still resolves). Capital `prefix+W` is unbound in both tmux's stock table and this repo's overrides (same live-server check), so it's used as the new table leader instead — no collision, and it keeps the worktree ("W") mnemonic.

`prefix+W c` -> claude worktree sessionizer, `prefix+W o` -> opencode variant. Placed near the existing `bind-key -r f run-shell "tmux neww ~/.local/scripts/tmux-sessionizer"` line. When the launched tool exits, the window closes automatically (default tmux pane-exit behavior) — same as the transient window `tmux-sessionizer` already produces (`ready-tmux` isn't a comparable example: it's typed into an already-running session's shell by `tmux-sessionizer`, not run as a window's sole process, so no auto-close event is tied to it); no `remain-on-exit` needed. One caveat: `exec claude-wt "$name"` hands off to `claude-wt`'s own `cmd_start`, which runs `offer_push_pr` after the inner `claude`/`opencode` process exits — an interactive `[Y/n]` push/PR prompt that blocks final termination whenever there are unpushed commits, so the window doesn't always close the instant the tool itself exits.

## Docs to update

- `claude/claude-wt-guide.md` (confirmed real file):
  - "Install the scripts" section (~lines 43-51) has an explicit-by-name (not glob) code block: `cp claude-wt git-wt ~/.local/bin/` and `chmod +x ~/.local/bin/claude-wt ~/.local/bin/git-wt`. Add `claude-wt-sessionizer` to *both* of these command lines (and to the `command -v claude-wt git-wt` sanity-check line right after), same reasoning as the standalone-installer fix above: a user following this guide's manual-install block verbatim, copy-pasting the commands as printed, would otherwise never get `claude-wt-sessionizer` onto PATH even after doing everything the guide says to do.
  - "Dependencies" section (~lines 22-39): add an `fzf` bullet in the same style as the existing `gh`/`tmux` bullets (optional, with a one-line "what it's for" clause and per-OS install command), e.g. `**fzf** (optional) — powers claude-wt-sessionizer's picker. macOS: `brew install fzf`. Linux: `sudo apt install fzf` / `sudo dnf install fzf`.` This is the doc-side counterpart to the fzf check already planned for `claude/standalone_quick_setup.sh`'s Dependencies section — a manual-stow user (this guide's own documented alternative to the standalone installer, so they never run that script's fzf check) needs the same warning here or they hit `claude-wt-sessionizer` refusing to start — its fzf-presence guard prints `claude-wt-sessionizer: fzf is required …` and exits — with no idea why fzf is suddenly needed.
  - Top-of-file "at a glance" command summary (~lines 8-14) and the "Quickstart" two-pane example section (~lines 97-105): add `claude-wt-sessionizer` and the `prefix+W c` keybind here too — these are the parts of the guide most likely to actually be read, and every bullet above this one only touches "Install the scripts"/"Dependencies," which a reader skimming just the top could miss entirely.
  - `claude/claude-wt-quickstart.md`: add `claude-wt-sessionizer` + the `prefix+W c` keybind.
- `opencode/opencode-wt-guide.md` (confirmed real file):
  - "Install the scripts" section (~lines 33-37) has the equivalent explicit-by-name code block: `cp opencode-wt opencode-git-wt opencode-open-wt ~/.local/bin/` and the matching `chmod +x` line. Add `opencode-wt-sessionizer` to both, same reasoning — the guide's own manual-install block is the thing users actually copy-paste, so it must list the new script by name too.
  - "Dependencies" section (~lines 23-33): add an `fzf` bullet matching this file's existing (more terse) bullet style, e.g. `**fzf** (optional) — powers opencode-wt-sessionizer's picker. `brew install fzf` / `sudo apt install fzf`.` Same rationale as the claude-side guide: the fzf check already planned for `opencode/standalone_quick_setup.sh` doesn't reach manual-stow users, so the guide itself needs its own warning.
  - Top-of-file "at a glance" command summary (~lines 8-15) and the "Quickstart" two-pane example section (~lines 76-84): same reasoning as the claude-side guide above — add `opencode-wt-sessionizer` and `prefix+W o` here too, not just in "Install the scripts"/"Dependencies."
  - `opencode/opencode-wt-quickstart.md`: add `opencode-wt-sessionizer` + the `prefix+W o` keybind.
- Root `AGENTS.md`: add the two new script names to the `claude/.local/scripts` and `opencode/.local/scripts` file-layout bullets.
- `claude/standalone_quick_setup.sh` (confirmed real file, "Scripts" section, lines ~106-119): the install mechanism there is not an array or a glob — it's three explicit lines naming each script by hand: the `for d in "$src" "$src/.local/scripts"` loop's existence check (`[ -f "$d/claude-wt" ] && [ -f "$d/git-wt" ]`), then a `rm -f "$BIN_DIR/claude-wt" "$BIN_DIR/git-wt"` line, then a `cp "$scripts_dir/claude-wt" "$scripts_dir/git-wt" "$BIN_DIR/"` line, then `chmod +x "$BIN_DIR/claude-wt" "$BIN_DIR/git-wt"`. Add `claude-wt-sessionizer` to **all four** of these lines, not just the `rm -f`/`cp`/`chmod +x` three: the existence check must become `[ -f "$d/claude-wt" ] && [ -f "$d/git-wt" ] && [ -f "$d/claude-wt-sessionizer" ]` as well. Leaving the check at 2 files while the `cp` line copies 3 creates a 2-check/3-copy mismatch: this script's own documented "flat copy" mode (a comment right above the loop says scripts can sit directly next to the setup script, no full repo checkout) only guarantees the files the check actually verifies. A flat-copy user who has only `claude-wt`+`git-wt` next to the setup script — the script's own supported case — passes the 2-file check, then the `cp` line fails on the not-yet-present `claude-wt-sessionizer` under `set -euo pipefail`, aborting the whole script before the PATH-setup and manual-steps sections below ever run. Extending the check to 3 files keeps it internally consistent and fails fast with the existing `die "claude-wt + git-wt not found next to this script"`-style message instead (that message's wording should also gain `+ claude-wt-sessionizer` to match).

  Also add an `fzf` dependency check in the "Dependencies" section (lines ~60-98), immediately after the existing `tmux` check, using the exact same `have`/`pkg_install` pattern already used there for `gh` and `tmux`:

  ```bash
  if have fzf; then
    echo "fzf - ok"
  else
    pkg_install fzf ||
      echo "(optional) no fzf — claude-wt-sessionizer's picker won't start until it's installed" >&2
  fi
  ```

  This mirrors `zsh/install.sh`'s existing `command -v fzf &>/dev/null || MISSING+=(fzf)` check (same "detect, don't assume present" intent), but standalone setup has no `MISSING` array — it reuses the same `have`/`pkg_install` idiom the file already uses for `gh`/`tmux`, not the `zsh/install.sh` array mechanism verbatim. Placed as a non-fatal, best-effort check like `gh`/`tmux` (not a `die`, since the rest of `claude-wt`/`git-wt` don't need fzf) — but the warning tells a standalone-only user who skips the install *now* why the sessionizer will later refuse to start, rather than leaving them to discover it via a transient window. (The sessionizer's own fzf-presence guard does print a clear `claude-wt-sessionizer: fzf is required …` message and `sleep`s ~2s before exiting, so it isn't silent — but in a `neww` window that closes right after, a ~2-second flash is still easy to miss, which is what this upfront installer warning guards against.)

- `opencode/standalone_quick_setup.sh` (confirmed real file, "Scripts" section, lines ~88-98): same explicit-filename-list mechanism — `for d in ...` loop checks `[ -f "$d/opencode-wt" ] && [ -f "$d/opencode-git-wt" ]`, then `rm -f "$BIN_DIR/opencode-wt" "$BIN_DIR/opencode-git-wt" "$BIN_DIR/opencode-open-wt"`, then the matching `cp` line, then `chmod +x` on those same three names. Note this file's existence check already only covers 2 of the 3 currently-copied names (it doesn't check for `opencode-open-wt`) — that's a pre-existing mismatch unrelated to this plan and out of scope; do not fix it here. For the new script, add `opencode-wt-sessionizer` to **all four** places consistently for the same reason as the claude-side fix above: the `rm -f`/`cp`/`chmod +x` lines *and* the existence check (`[ -f "$d/opencode-wt" ] && [ -f "$d/opencode-git-wt" ] && [ -f "$d/opencode-wt-sessionizer" ]`). Adding it to the check keeps the new script's own check/copy pairing internally consistent, even though it doesn't retroactively fix the pre-existing `opencode-open-wt` gap — the two are independent additions to the same check expression, not a fix for the old bug. Unlike the claude-side fix above, this file's `die` message (`die "opencode-wt scripts not found next to this one"`) is already generic/unenumerated, so — unlike the claude-side message, which names files by hand and needs `+ opencode-wt-sessionizer` appended — it needs no wording update here.

  Also add the same `fzf` dependency check in this file's "Dependencies" section (lines ~50-81), immediately after its existing `tmux` check, same `have`/`pkg_install` pattern, just the warning text swapped to name `opencode-wt-sessionizer`:

  ```bash
  if have fzf; then
    echo "fzf - ok"
  else
    pkg_install fzf ||
      echo "(optional) no fzf — opencode-wt-sessionizer's picker won't start until it's installed" >&2
  fi
  ```

- `claude/install.sh` and `opencode/install.sh` (confirmed real files — the per-package installers that the repo root's own `install.sh` runs after stowing each package): add an fzf dependency check to both, using the exact one-line guard idiom each file already uses for its own other tool checks — not the `MISSING` array pattern from `zsh/install.sh`, and not the `have`/`pkg_install` pattern from the standalone setup scripts above (those are different files with different existing idioms; this fix must match each target file's *own* pattern).
  - `claude/install.sh` line 3 is `command -v jq &>/dev/null || brew install jq`. Add a matching line, e.g. `command -v fzf &>/dev/null || brew install fzf`.
  - `opencode/install.sh` line 5 is `command -v opencode &>/dev/null || brew install opencode`. Add a matching line, e.g. `command -v fzf &>/dev/null || brew install fzf`.

  Note on the primary path: running the repo root's own `install.sh` normally already guarantees fzf gets installed, regardless of whether the user chooses to stow `zsh` itself. That's because root `install.sh` has two separate loops — a stow loop (per-package or "stow all"), and then a second, unconditional "Running install scripts" loop that runs *every* package's `install.sh` (including `zsh/install.sh`) no matter which packages were actually stowed. Since `zsh/install.sh` unconditionally does `command -v fzf &>/dev/null || MISSING+=(fzf)` followed by `brew install "${MISSING[@]}"`, fzf ends up installed on any normal root-`install.sh` run even if the user declined to stow `zsh`. So the two lines below are not closing a gap in that primary path.

  The real, narrower gap they close: a user who runs a package's `install.sh` standalone, directly — e.g. `bash claude/install.sh` or `bash opencode/install.sh` on its own, without ever invoking the repo root's `install.sh` — never triggers `zsh/install.sh`'s install-script loop at all, so fzf never gets installed via that path. Adding the check directly to `claude/install.sh`/`opencode/install.sh` closes that direct-invocation gap as defense-in-depth, independent of the root-`install.sh` path where the gap doesn't actually exist. Since `claude/install.sh` and `opencode/install.sh` are copied verbatim into the repo (not templated), this is a plan-doc instruction to add the line to each file — no separate script or shared mechanism to design.

No new stow package, no `.stow-local-ignore` changes — both scripts land in existing packages' already-stowed `.local/scripts/` dirs; tmux.conf is edited in place. This still requires a re-stow step after creating the files, though: on this machine `~/.local/scripts/claude-wt` etc. are individual per-file symlinks (`~/.local/scripts/claude-wt -> ../../dotfiles/claude/.local/scripts/claude-wt`), not a symlinked directory — Stow does not retroactively create a symlink for a file added to an already-stowed package after the fact. So after creating `claude-wt-sessionizer`/`opencode-wt-sessionizer`, re-run `stow claude`/`stow opencode` (or re-run the repo root's `install.sh`) before testing the tmux integration, or the `prefix+W c`/`prefix+W o` bindings will fail with "No such file or directory" since the new scripts won't exist yet at `~/.local/scripts/`.

## Verification

- `bash -n` both new scripts.
- Before anything else: confirm `~/.local/scripts/claude-wt-sessionizer` and `~/.local/scripts/opencode-wt-sessionizer` actually resolve (`ls -l`) — if the re-stow step above was skipped, they won't exist yet and every later step will fail with a misleading "command not found" rather than any of this plan's other guarded failure modes.
- Confirm both new scripts are executable (`ls -l` or `test -x`) before doing anything else — a missing `chmod +x` fails instantly with no readable message at all, unlike the guarded fzf-missing/git-repo cases (which print a message and pause for ~2s), so checking this first rules out the one failure mode with zero on-screen feedback before testing the others.
- Run each script directly outside tmux (fzf still works in a plain terminal) to check: list renders, `ctrl-n` + a bad name (e.g. with a space) shows the error and redisplays, `ctrl-n` + an existing name shows the "already exists" error, `ctrl-n` + a fresh valid name reaches the `exec claude-wt`/`opencode-wt` line (Ctrl-C right before/at that point to avoid actually spawning a session during the test), and a failed `ctrl-n` attempt redisplays with the typed name still in the query box rather than a blank one. Also run it from a directory outside any git repo and confirm the guard message appears instead of a silent/blank picker.
- Type a query that matches nothing and then press Esc (and separately Ctrl-C) — confirm the script exits cleanly rather than looping back into the "no match — press ctrl-n" redisplay. This is the specific case the `[ "$rc" -eq 130 ] && exit 0` handling protects: it must exit regardless of whether fzf left the typed text in the query line on abort.
- `prefix+r` to reload tmux.conf, then `tmux list-keys -T wt` to confirm both bindings registered, and `tmux list-keys -T prefix | grep -E '^bind-key +-T prefix +w '` to confirm lowercase `prefix+w` still resolves to the stock `choose-tree -Zw` (untouched) — a plain `grep -w w` also matches unrelated `-w` flags elsewhere in this file's bindings (e.g. the `C-o`/`C-c` popups' `-w 95%`), so anchor on the table/key fields specifically.
- Press `prefix+W c` from a pane whose cwd is a *different* git repo than the tmux session's start directory — confirms `-c "#{pane_current_path}"` is actually taking effect and the sessionizer operates on the pane's repo, not the session's start dir.
- Double-click a row instead of pressing Enter — confirms the `*)` arm's `$sel`-based disambiguation (not key-identity-based) correctly opens the same worktree Enter would.
- One real end-to-end run, in two parts since color behavior is conditional: (a) `prefix+W c`, create a fresh throwaway name via `ctrl-n` with no color ever set for it — confirm the window is *not* renamed (tmux's default auto-name persists; this is expected, not a bug, since `apply_color` only renames when a color is set); (b) separately, pick or create a name that already has a saved color from a prior `claude-wt <name> <color>` run — confirm that window *is* renamed and tinted. Either way, exit and confirm the window closes (allowing for `offer_push_pr`'s prompt if there are unpushed commits); `claude-wt -d <name>` to clean up.

## Relevant existing code for reference

### claude-wt -l output format (claude/.local/scripts/claude-wt, cmd_list)

```
cmd_list() {
  local root=$1 prefix path branch name color dirty line
  prefix="$root/.worktrees/"
  printf '%-20s %-20s %-8s %s\n' NAME BRANCH COLOR STATE
  git -C "$root" worktree list --porcelain | while IFS= read -r line; do
    case "$line" in
      "worktree "*)
        path=${line#worktree }
        continue
        ;;
      "branch refs/heads/"*) branch=${line#branch refs/heads/} ;;
      detached) branch="(detached)" ;;
      *) continue ;;
    esac
    case "$path" in
      "$prefix"*)
        name=${path#"$prefix"}
        color=$(git -C "$root" config --get "wt.$name.color" 2>/dev/null || echo -)
        if [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]; then
          dirty=dirty
        else
          dirty=clean
        fi
        printf '%-20s %-20s %-8s %s\n' "$name" "$branch" "$color" "$dirty"
        ;;
    esac
  done
}
```

Note: names containing slashes (e.g. `feat/x`) print with the slash intact in the NAME column (first awk field would be truncated at slash-adjacent whitespace only, not at the slash itself — awk `$1` splits on whitespace, so `feat/x` stays as one token). `claude-wt`'s own `cmd_start`/`cmd_done` already handle slashed names (parent-dir cleanup loop in `cmd_done`), so the sessionizer's `awk '{print $1}'` extraction is consistent with that.

### tmux.conf existing binding pattern (tmux/.config/tmux/tmux.conf)

```
unbind -T copy-mode-vi Space
bind -T copy-mode-vi v send-keys -X begin-selection
...
bind c new-window -c "#{pane_current_path}"
bind \ split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
...
bind-key -r f run-shell "tmux neww ~/.local/scripts/tmux-sessionizer"
...
bind C-o popup -E -d "#{pane_current_path}" -w 95% -h 95% "opencode"
bind C-c popup -E -d "#{pane_current_path}" -w 95% -h 95% "claude"
```

### claude-wt apply_color (renames window to session name)

```
apply_color() {
  local name=$1 tint=$2
  [ -n "$tint" ] || return 0
  if [ -n "${TMUX:-}" ]; then
    prev_pane_bg=$(tmux display -p '#{pane_bg}' 2>/dev/null || true)
    prev_win_name=$(tmux display -p '#{window_name}' 2>/dev/null || true)
    prev_autorename=$(tmux show -wv automatic-rename 2>/dev/null || true)
    tmux select-pane -P "bg=$tint" 2>/dev/null || true
    tmux rename-window "$name" 2>/dev/null || true
  else
    printf '\033]11;%s\007' "$tint"
  fi
}
```

Both the rename and the tint are gated on the same `[ -n "$tint" ] || return 0` guard — a worktree with no saved color gets neither. See the two-part Verification bullet above for what to actually expect from each case.
