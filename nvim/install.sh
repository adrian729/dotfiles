#!/bin/bash

MISSING=()
command -v lua-language-server &>/dev/null || MISSING+=(lua-language-server)
command -v marksman &>/dev/null || MISSING+=(marksman)
command -v nvim &>/dev/null || MISSING+=(neovim)
command -v pyright &>/dev/null || MISSING+=(pyright)
command -v rust-analyzer &>/dev/null || MISSING+=(rust-analyzer)
command -v stylua &>/dev/null || MISSING+=(stylua)
command -v ruff &>/dev/null || MISSING+=(ruff)
[ ${#MISSING[@]} -gt 0 ] && brew install "${MISSING[@]}"

# llvm is keg-only — shared handling lives in clangd/install.sh (sibling package)
clangd_install="$(dirname "$0")/../clangd/install.sh"
if [ -f "$clangd_install" ]; then
  source "$clangd_install"
  ensure_llvm clangd clang-format
else
  echo "clangd/install.sh not found — skipping llvm/clangd-format symlink setup" >&2
fi
