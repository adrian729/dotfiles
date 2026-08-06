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

if command -v nvim &>/dev/null; then
  echo "Installing Neovim plugins (lazy.nvim)..."
  nvim --headless -c "qa" 2>&1

  # markdown-preview.nvim's declared build step (vim.fn["mkdp#util#install"]()) runs during
  # lazy.nvim's install pipeline before the plugin is ever added to &rtp, so the autoload
  # function it needs can't resolve — it fails with E117 on every fresh install (not a
  # one-off network blip) and lazy.nvim never retries a plugin it considers installed.
  # Run the plugin's own installer script directly instead of routing through vim/autoload.
  mkdp_app="$HOME/.local/share/nvim/lazy/markdown-preview.nvim/app"
  if [ -f "$mkdp_app/install.sh" ] && [ -z "$(ls -A "$mkdp_app/bin" 2>/dev/null)" ]; then
    echo "Building markdown-preview.nvim (fetching preview server binary)..."
    sh "$mkdp_app/install.sh"
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
