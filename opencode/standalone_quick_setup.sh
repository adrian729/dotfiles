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
have_opencode() { have opencode || [ -x "$BIN_DIR/opencode" ]; }

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
  if [ -f "$d/opencode-wt" ] && [ -f "$d/opencode-git-wt" ]; then
    scripts_dir=$d
    break
  fi
done
[ -n "$scripts_dir" ] || die "opencode-wt scripts not found next to this one"

mkdir -p "$SCRIPTS_DIR"
# rm first: cp would write THROUGH an existing symlink (stow users) and die
# outright on a dangling one.
rm -f "$SCRIPTS_DIR/opencode-wt" "$SCRIPTS_DIR/opencode-git-wt" "$SCRIPTS_DIR/opencode-open-wt"
cp "$scripts_dir/opencode-wt" "$scripts_dir/opencode-git-wt" "$scripts_dir/opencode-open-wt" "$SCRIPTS_DIR/"
chmod +x "$SCRIPTS_DIR/opencode-wt" "$SCRIPTS_DIR/opencode-git-wt" "$SCRIPTS_DIR/opencode-open-wt"
echo "installed to $SCRIPTS_DIR"

case ":$PATH:" in
  *":$SCRIPTS_DIR:"*) echo "$SCRIPTS_DIR already on PATH - ok" ;;
  *)
    rc="$HOME/.bashrc"
    case "${SHELL:-}" in */zsh) rc="$HOME/.zshrc" ;; esac
    line='export PATH="$HOME/.local/scripts:$PATH"'
    if grep -qsE '^[^#]*(\$\{?HOME\}?|~)/\.local/scripts([:"/ ]|$)' "$rc"; then
      echo "$rc already puts ~/.local/scripts on PATH — restart your shell"
    elif ask "$SCRIPTS_DIR is not on PATH — append to $rc?"; then
      printf '\n%s # opencode-wt setup\n' "$line" >>"$rc"
      echo "added to $rc — restart shell or run: $line"
    fi
    ;;
esac

say "Manual steps"
have_opencode && echo "- run 'opencode' once to log in (if you haven't)"
if have gh && ! gh auth status >/dev/null 2>&1; then
  echo "- run 'gh auth login' for draft-PR automation"
fi
echo "- add git push deny to ~/.config/opencode/opencode.json:"
echo '  { "permission": { "bash": { "*": "allow", "git push *": "deny" } } }'
echo "- smoke test:  cd <some-git-repo> && opencode-wt hello green"
echo ""
echo "Docs: opencode-wt-quickstart.md / opencode-wt-guide.md"
