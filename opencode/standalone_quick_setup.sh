#!/usr/bin/env bash
# standalone_quick_setup.sh — best-effort one-shot setup for opencode-wt +
# opencode-git-wt on a fresh macOS or Linux machine.
set -euo pipefail

# Same destination the dotfiles repo stows to, so a machine that later gets the
# repo stowed has one canonical location for these scripts instead of two.
SCRIPTS_DIR="$HOME/.local/scripts"
# Where a CLI installer would put its own binary — unrelated to SCRIPTS_DIR.
BIN_DIR="$HOME/.local/bin"

say() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
die() { echo "setup: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
have_opencode() { have opencode || [ -x "$HOME/.opencode/bin/opencode" ] || [ -x "$BIN_DIR/opencode" ]; }

ask() {
  local ans
  printf '%s [Y/n] ' "$1"
  read -r ans || ans=n
  case "$ans" in n|N|no|NO) return 1 ;; *) return 0 ;; esac
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

say "Dependencies"

if have git; then
  echo "git $(git version | awk '{print $3}') - ok"
else
  echo "git missing."
  pkg_install git || die "git is required"
fi

have jq || pkg_install jq || die "jq is required for session tracking"

if have_opencode; then
  echo "opencode - ok"
else
  echo "OpenCode missing."
  if ask "Install it (npm install -g opencode-ai)?"; then
    npm install -g opencode-ai ||
      echo "setup: warning: install failed — install manually" >&2
  else
    echo "setup: warning: opencode-wt cannot start sessions without it" >&2
  fi
fi

if have gh; then
  echo "gh - ok"
else
  pkg_install gh || echo "(optional) no gh — manual draft PR creation" >&2
fi

if have tmux; then
  echo "tmux - ok"
else
  pkg_install tmux || echo "(optional) no tmux — background tint fallback" >&2
fi

say "Scripts"

src=$(cd "$(dirname "$0")" && pwd)
scripts_dir=""
for d in "$src" "$src/.local/scripts"; do
  if [ -f "$d/opencode-wt" ] && [ -f "$d/opencode-git-wt" ] && [ -f "$d/opencode-open-wt" ]; then
    scripts_dir=$d
    break
  fi
done
[ -n "$scripts_dir" ] || die "opencode-wt scripts not found next to this one"

mkdir -p "$SCRIPTS_DIR"
for script in opencode-wt opencode-git-wt opencode-open-wt; do
  source_file="$scripts_dir/$script"
  target_file="$SCRIPTS_DIR/$script"
  # Also handles running a flat setup from the destination itself.
  if [ -e "$target_file" ] && cmp -s "$source_file" "$target_file"; then
    continue
  fi
  if [ -e "$target_file" ] || [ -L "$target_file" ]; then
    backup_root="$HOME/.local/state/dotfiles/backups"
    mkdir -p "$backup_root"
    backup_dir=$(mktemp -d "$backup_root/opencode-setup.XXXXXX")
    mv "$target_file" "$backup_dir/"
    echo "Preserved $target_file in $backup_dir"
  fi
  cp "$source_file" "$target_file"
  chmod +x "$target_file"
done
echo "installed to $SCRIPTS_DIR"

# This file is sourced by the dotfiles shell configuration. Keep machine-local
# additions here, even when a shell rc file is a symlink into a repository.
profile="$HOME/.local/.local_profile"
line='export PATH="$HOME/.local/scripts:$HOME/.local/bin:$HOME/.opencode/bin:$PATH"'
if ! grep -qxF "$line # opencode-wt setup" "$profile" 2>/dev/null; then
  printf '\n%s # opencode-wt setup\n' "$line" >> "$profile"
fi
echo "PATH setup saved in $profile; load it with: . \"\$HOME/.local/.local_profile\""
echo "For a shell without the dotfiles setup, arrange to source that local profile at startup."

say "Manual steps"
have_opencode && echo "- run 'opencode' once to log in (if you haven't)"
if have gh && ! gh auth status >/dev/null 2>&1; then
  echo "- run 'gh auth login' for draft-PR automation"
fi
echo "- smoke test:  cd <some-git-repo> && opencode-wt hello green"
echo ""
echo "Docs: opencode-wt-quickstart.md / opencode-wt-guide.md"
