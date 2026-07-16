#!/bin/bash

# llvm is keg-only (not linked onto PATH by brew) — this installs it if any
# requested tool binary is missing, then symlinks each into ~/.local/bin.
# Shared with nvim/install.sh (sources this file for clang-format too).
ensure_llvm() {
  local tools=("$@") llvm_root="" tool src dst need_install=0

  for tool in "${tools[@]}"; do
    command -v "$tool" &>/dev/null && continue
    [ -f "/opt/homebrew/opt/llvm/bin/$tool" ] && continue
    [ -f "/usr/local/opt/llvm/bin/$tool" ] && continue
    need_install=1
  done
  [ "$need_install" -eq 1 ] && brew install llvm

  [ -f /opt/homebrew/opt/llvm/bin/clangd ] && llvm_root="/opt/homebrew/opt/llvm"
  [ -f /usr/local/opt/llvm/bin/clangd ] && llvm_root="/usr/local/opt/llvm"
  [ -z "$llvm_root" ] && return 0

  mkdir -p ~/.local/bin
  for tool in "${tools[@]}"; do
    src="$llvm_root/bin/$tool"
    dst="$HOME/.local/bin/$tool"
    if [ -f "$src" ]; then
      case "$dst" in "$HOME"/.local/bin/*) rm -f "$dst" ;; esac
      ln -s "$src" "$dst"
    fi
  done
}

# Only run standalone when executed directly — nvim/install.sh sources this
# file and calls ensure_llvm itself with its own tool list.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  ensure_llvm clangd
fi
