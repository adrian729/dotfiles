#!/bin/bash

MISSING=()
command -v lua-language-server &>/dev/null || MISSING+=(lua-language-server)
command -v marksman &>/dev/null || MISSING+=(marksman)
command -v nvim &>/dev/null || MISSING+=(neovim)
command -v pyright &>/dev/null || MISSING+=(pyright)
command -v rust-analyzer &>/dev/null || MISSING+=(rust-analyzer)
command -v stylua &>/dev/null || MISSING+=(stylua)
command -v ruff &>/dev/null || MISSING+=(ruff)
# llvm is keg-only — clangd may not be on PATH
if ! command -v clangd &>/dev/null \
  && [ ! -f /opt/homebrew/opt/llvm/bin/clangd ] \
  && [ ! -f /usr/local/opt/llvm/bin/clangd ]; then
  MISSING+=(llvm)
fi
[ ${#MISSING[@]} -gt 0 ] && brew install "${MISSING[@]}"

llvm_root=""
[ -f /opt/homebrew/opt/llvm/bin/clangd ] && llvm_root="/opt/homebrew/opt/llvm"
[ -f /usr/local/opt/llvm/bin/clangd ] && llvm_root="/usr/local/opt/llvm"
if [ -n "$llvm_root" ]; then
  mkdir -p ~/.local/bin
  for tool in clangd clang-format; do
    src="$llvm_root/bin/$tool"
    dst="$HOME/.local/bin/$tool"
    [ -f "$src" ] && [ ! -e "$dst" ] && ln -s "$src" "$dst"
  done
fi
