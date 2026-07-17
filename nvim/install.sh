#!/bin/bash

nvim_ge_012() {
  local ver major minor
  ver="$(nvim --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
  [ -n "$ver" ] || return 1
  major="${ver%%.*}"
  minor="${ver##*.}"
  [ "$major" -gt 0 ] || [ "$minor" -ge 12 ]
}

nvim_present=0
command -v nvim &>/dev/null && nvim_present=1

MISSING=()
command -v lua-language-server &>/dev/null || MISSING+=(lua-language-server)
command -v marksman &>/dev/null || MISSING+=(marksman)
command -v nvim &>/dev/null || MISSING+=(neovim)
command -v pyright &>/dev/null || MISSING+=(pyright)
command -v rust-analyzer &>/dev/null || MISSING+=(rust-analyzer)
command -v stylua &>/dev/null || MISSING+=(stylua)
command -v ruff &>/dev/null || MISSING+=(ruff)
[ ${#MISSING[@]} -gt 0 ] && brew install "${MISSING[@]}"

if command -v nvim &>/dev/null && ! nvim_ge_012; then
  cur="$(nvim --version | head -1)"
  if [ "$nvim_present" -eq 1 ]; then
    echo "WARNING: existing $cur predates 0.12 — this config needs 0.12+. Upgrade with: brew upgrade neovim" >&2
  else
    echo "WARNING: installed $cur predates 0.12 — this config needs 0.12+." >&2
  fi
fi

# llvm is keg-only — shared handling lives in clangd/install.sh (sibling package)
clangd_install="$(dirname "$0")/../clangd/install.sh"
if [ -f "$clangd_install" ]; then
  source "$clangd_install"
  ensure_llvm clangd clang-format
else
  echo "clangd/install.sh not found — skipping llvm/clangd-format symlink setup" >&2
fi
