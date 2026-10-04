#!/bin/bash

. "$(dirname "$0")/../lib/common.sh"

brew_shellenv 2>/dev/null

# llvm is keg-only (not linked onto PATH by brew) — this installs it if any
# requested tool binary is missing, then symlinks each into ~/.local/bin.
# Shared with nvim/install.sh (sources this file for clang-format too).
ensure_llvm() {
  local tools=("$@") llvm_root="" tool src dst need_install=0

  for tool in "${tools[@]}"; do
    command -v "$tool" &>/dev/null && continue
    [ -f "/opt/homebrew/opt/llvm/bin/$tool" ] && continue
    [ -f "/usr/local/opt/llvm/bin/$tool" ] && continue
    [ -f "/home/linuxbrew/.linuxbrew/opt/llvm/bin/$tool" ] && continue
    need_install=1
  done
  if [ "$need_install" -eq 1 ]; then
    if have brew; then
      brew install llvm || { warn "brew install llvm failed — ${tools[*]} unavailable"; return 1; }
    else
      warn "brew unavailable — install llvm manually for ${tools[*]}"
      return 1
    fi
  fi

  [ -d /opt/homebrew/opt/llvm/bin ] && llvm_root="/opt/homebrew/opt/llvm"
  [ -d /usr/local/opt/llvm/bin ] && llvm_root="/usr/local/opt/llvm"
  [ -d /home/linuxbrew/.linuxbrew/opt/llvm/bin ] && llvm_root="/home/linuxbrew/.linuxbrew/opt/llvm"
  [ -z "$llvm_root" ] && return 0

  mkdir -p "$HOME/.local/bin" || return 1
  for tool in "${tools[@]}"; do
    src="$llvm_root/bin/$tool"
    dst="$HOME/.local/bin/$tool"
    if [ -f "$src" ]; then
      if [ -e "$dst" ] || [ -L "$dst" ]; then
        [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ] && continue
        warn "preserving existing $dst"
        continue
      fi
      ln -s "$src" "$dst" || return 1
    fi
  done
}

# Only run standalone when executed directly — nvim/install.sh sources this
# file and calls ensure_llvm itself with its own tool list.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  ensure_llvm clangd
fi
