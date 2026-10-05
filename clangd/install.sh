#!/bin/bash

. "$(dirname "$0")/../lib/common.sh"

brew_shellenv 2>/dev/null

# clangd and clang-format, for nvim and Claude's C/C++ support. Homebrew's
# llvm is keg-only (not linked onto PATH), so each tool is symlinked from the
# keg into ~/.local/bin. Where Homebrew cannot pour llvm (Intel macOS builds it
# from source for hours), or the keg no longer runs, the tools come from their
# PyPI builds via uv instead. Shared with nvim/install.sh, which sources this
# file and calls ensure_llvm itself.

# Present means runs: a keg whose libraries were upgraded out from under it
# (libz3, say) keeps its binaries on disk but cannot load them.
# The subshell keeps bash's own "Abort trap" report for a binary that dies
# loading its libraries out of the output.
_tool_runs() { ("$1" --version >/dev/null 2>&1) 2>/dev/null; }

_llvm_root() {
  local root
  for root in /opt/homebrew/opt/llvm /usr/local/opt/llvm /home/linuxbrew/.linuxbrew/opt/llvm; do
    [ -d "$root/bin" ] && { echo "$root"; return 0; }
  done
  return 1
}

ensure_llvm() {
  local tool root dst status=0

  for tool in "$@"; do
    dst="$HOME/.local/bin/$tool"
    _tool_runs "$dst" && continue

    # A link this script made into a keg that no longer runs is replaced;
    # anything else already there belongs to the user.
    if [ -L "$dst" ]; then
      case "$(readlink "$dst")" in */opt/llvm/bin/*) rm -f "$dst" ;; esac
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
      warn "preserving existing $dst"
      continue
    fi

    # A working keg wins over the PATH copy (often an older Apple or distro
    # build) and is linked where nvim looks first. With no keg, a working PATH
    # copy is enough: no reason to install llvm over it.
    root=$(_llvm_root)
    if [ -z "$root" ]; then
      _tool_runs "$tool" && continue
      brew_can_pour llvm && brew install llvm && root=$(_llvm_root)
    fi
    if [ -n "$root" ] && _tool_runs "$root/bin/$tool"; then
      mkdir -p "$HOME/.local/bin" && ln -s "$root/bin/$tool" "$dst" || status=1
      continue
    fi
    # A keg that no longer runs leaves nvim's PATH fallback to a working copy.
    _tool_runs "$tool" && continue

    [ -z "$root" ] || warn "$root/bin/$tool does not run — installing $tool from PyPI instead"
    uv_tool "$tool" && _tool_runs "$dst" || {
      warn "$tool unavailable"
      status=1
    }
  done
  return "$status"
}

# Only run standalone when executed directly — nvim/install.sh sources this
# file and calls ensure_llvm itself with its own tool list.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  ensure_llvm clangd
fi
