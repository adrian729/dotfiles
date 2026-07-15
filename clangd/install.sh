#!/bin/bash

if ! command -v clangd &>/dev/null \
  && [ ! -f /opt/homebrew/opt/llvm/bin/clangd ] \
  && [ ! -f /usr/local/opt/llvm/bin/clangd ]; then
  brew install llvm
fi

llvm_root=""
[ -f /opt/homebrew/opt/llvm/bin/clangd ] && llvm_root="/opt/homebrew/opt/llvm"
[ -f /usr/local/opt/llvm/bin/clangd ] && llvm_root="/usr/local/opt/llvm"
if [ -n "$llvm_root" ]; then
  mkdir -p ~/.local/bin
  for tool in clangd; do
    src="$llvm_root/bin/$tool"
    dst="$HOME/.local/bin/$tool"
    if [ -f "$src" ]; then
      case "$dst" in "$HOME"/.local/bin/*) rm -f "$dst" ;; esac
      ln -s "$src" "$dst"
    fi
  done
fi
