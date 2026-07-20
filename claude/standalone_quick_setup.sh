#!/usr/bin/env bash
# standalone_quick_setup.sh — best-effort one-shot setup for claude-wt +
# git-wt on a fresh macOS or Linux machine: installs missing dependencies
# (asking first), puts both scripts on your PATH, and lists the login steps
# it can't do for you. Safe to re-run — every step skips itself when done.
set -euo pipefail

BIN_DIR="$HOME/.local/bin"

say() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
die() {
  echo "setup: $*" >&2
  exit 1
}
have() { command -v "$1" >/dev/null 2>&1; }
# The Claude installer drops the binary in ~/.local/bin, which may not be on
# PATH yet during this run — check the destination too.
have_claude() { have claude || [ -x "$BIN_DIR/claude" ]; }

ask() {
  local ans
  printf '%s [Y/n] ' "$1"
  read -r ans || ans=n # EOF (non-interactive) → no
  case "$ans" in
    n | N | no | NO) return 1 ;;
    *) return 0 ;;
  esac
}

PKG=""
if have brew; then
  PKG="brew install"
elif have apt-get; then
  PKG="sudo apt-get install -y"
elif have dnf; then
  PKG="sudo dnf install -y"
elif have pacman; then
  PKG="sudo pacman -S --noconfirm"
fi

pkg_install() {
  if [ -z "$PKG" ]; then
    echo "setup: no package manager found — install '$1' manually" >&2
    return 1
  fi
  ask "Install $1 ($PKG $1)?" || return 1
  $PKG "$1"
}

git_recent_enough() {
  have git || return 1
  local v major minor
  v=$(git version | awk '{print $3}')
  major=${v%%.*}
  minor=${v#*.}
  minor=${minor%%.*}
  [ "$major" -gt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -ge 31 ]; }
}

say "Dependencies"

if git_recent_enough; then
  echo "git $(git version | awk '{print $3}') - ok"
else
  echo "git >= 2.31 missing."
  pkg_install git || {
    [ "$(uname)" = Darwin ] && echo "  hint: xcode-select --install" >&2
    die "git >= 2.31 is required"
  }
  git_recent_enough || die "installed git is still < 2.31 — upgrade it manually"
fi

if have_claude; then
  echo "claude - ok"
else
  echo "Claude Code missing."
  if ask "Install it (curl -fsSL https://claude.ai/install.sh | bash)?"; then
    curl -fsSL https://claude.ai/install.sh | bash ||
      echo "setup: warning: Claude Code install failed — install it manually later" >&2
  else
    echo "setup: warning: claude-wt cannot start sessions without it" >&2
  fi
fi

if have gh; then
  echo "gh - ok"
else
  pkg_install gh ||
    echo "(optional) no gh — you keep the push, lose automatic draft PRs:" \
      "https://github.com/cli/cli/blob/trunk/docs/install_linux.md" >&2
fi

if have tmux; then
  echo "tmux - ok"
else
  pkg_install tmux ||
    echo "(optional) no tmux — pane tints fall back to the terminal background" >&2
fi

if have fzf; then
  echo "fzf - ok"
else
  pkg_install fzf ||
    echo "(optional) no fzf — claude-wt-sessionizer's picker won't start until it's installed" >&2
fi

say "Scripts"

# Find claude-wt + git-wt next to this script (flat copy) or in the repo
# layout (.local/scripts/).
src=$(cd "$(dirname "$0")" && pwd)
scripts_dir=""
for d in "$src" "$src/.local/scripts"; do
  if [ -f "$d/claude-wt" ] && [ -f "$d/git-wt" ] && [ -f "$d/claude-wt-sessionizer" ]; then
    scripts_dir=$d
    break
  fi
done
[ -n "$scripts_dir" ] || die "claude-wt + git-wt + claude-wt-sessionizer not found next to this script"

mkdir -p "$BIN_DIR"
# rm first: cp would write THROUGH an existing symlink (stow users) and die
# outright on a dangling one.
rm -f "$BIN_DIR/claude-wt" "$BIN_DIR/git-wt" "$BIN_DIR/claude-wt-sessionizer"
cp "$scripts_dir/claude-wt" "$scripts_dir/git-wt" "$scripts_dir/claude-wt-sessionizer" "$BIN_DIR/"
chmod +x "$BIN_DIR/claude-wt" "$BIN_DIR/git-wt" "$BIN_DIR/claude-wt-sessionizer"
echo "installed to $BIN_DIR"

case ":$PATH:" in
  *":$BIN_DIR:"*) echo "$BIN_DIR already on PATH - ok" ;;
  *)
    rc="$HOME/.bashrc"
    case "${SHELL:-}" in */zsh) rc="$HOME/.zshrc" ;; esac
    line='export PATH="$HOME/.local/bin:$PATH"'
    # Match $HOME/${HOME}/~ forms, skip commented lines, and don't match
    # longer paths like ~/.local/binaries.
    if grep -qsE '^[^#]*(\$\{?HOME\}?|~)/\.local/bin([:"/ ]|$)' "$rc"; then
      echo "$rc already puts ~/.local/bin on PATH — restart your shell to pick it up"
    elif ask "$BIN_DIR is not on PATH — append the export to $rc?"; then
      printf '\n%s # claude-wt setup\n' "$line" >>"$rc"
      echo "added to $rc — restart your shell (or run: $line)"
    else
      echo "add it yourself: $line"
    fi
    ;;
esac

say "Manual steps (logins can't be scripted)"
have_claude && echo "- run 'claude' once in any folder to log in (if you haven't)"
if have gh && ! gh auth status >/dev/null 2>&1; then
  echo "- run 'gh auth login' for the draft-PR automation"
fi
echo "- smoke test:  cd <some-git-repo> && claude-wt hello green"
echo ""
echo "Docs: claude-wt-quickstart.md (usage) / claude-wt-guide.md (everything)"
