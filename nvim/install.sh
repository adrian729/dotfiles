#!/bin/bash

. "$(dirname "$0")/../lib/common.sh"

brew_shellenv 2>/dev/null
install_status=0

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
command -v rust-analyzer &>/dev/null || MISSING+=(rust-analyzer)
command -v stylua &>/dev/null || MISSING+=(stylua)
command -v rg &>/dev/null || MISSING+=(ripgrep)
command -v ruff &>/dev/null || MISSING+=(ruff)
command -v ty &>/dev/null || MISSING+=(ty)
command -v tree-sitter &>/dev/null || MISSING+=(tree-sitter-cli)
if [ ${#MISSING[@]} -gt 0 ]; then
  if have brew; then
    brew install "${MISSING[@]}" || install_status=1
  else
    warn "brew unavailable — missing: ${MISSING[*]}"
    install_status=1
  fi
fi

# nvim-treesitter compiles every parser with a C compiler and
# telescope-fzf-native's spec is `build = "make"`. macOS gets both from the
# Command Line Tools; a fresh Debian/Ubuntu has neither.
ensure_build_tools || install_status=1

# lazy.nvim clones every plugin over git, and markdown-preview.nvim's installer
# (run further down) fetches its server binary over curl.
for tool in git curl; do
  have "$tool" || { is_linux && pkg_install "$tool"; } || {
    warn "$tool missing — plugin installs may fail"
    install_status=1
  }
done

# opt.clipboard = "unnamedplus" needs a clipboard provider to exist.
ensure_clipboard || install_status=1

if command -v nvim &>/dev/null && ! nvim_ge_012; then
  cur="$(nvim --version | head -1)"
  if [ "$nvim_present" -eq 1 ]; then
    echo "WARNING: existing $cur predates 0.12 — this config needs 0.12+. Upgrade with: brew upgrade neovim" >&2
  else
    echo "WARNING: installed $cur predates 0.12 — this config needs 0.12+." >&2
  fi
  install_status=1
fi

if command -v nvim &>/dev/null && nvim_ge_012; then
  echo "Installing Neovim plugins (lazy.nvim)..."
  DOTFILES_NVIM_BOOTSTRAP=1 nvim --headless -c "qa" 2>&1 || install_status=1

  # Repair plugins left without a binary by the old autoload build callback.
  mkdp_app="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/markdown-preview.nvim/app"
  mkdp_has_binary() {
    local binary
    for binary in "$mkdp_app"/bin/markdown-preview-*; do
      [ -f "$binary" ] && [ -x "$binary" ] && return 0
    done
    return 1
  }
  if [ -f "$mkdp_app/install.sh" ] && ! mkdp_has_binary; then
    echo "Building markdown-preview.nvim (fetching preview server binary)..."
    bash "$mkdp_app/install.sh" || install_status=1
  fi
  if ! mkdp_has_binary; then
    warn "Markdown Preview server is missing; check its plugin build output"
    install_status=1
  fi
else
  install_status=1
fi

# llvm is keg-only — shared handling lives in clangd/install.sh (sibling package)
clangd_install="$(dirname "$0")/../clangd/install.sh"
if [ -f "$clangd_install" ]; then
  source "$clangd_install"
  ensure_llvm clangd clang-format || install_status=1
else
  echo "clangd/install.sh not found — skipping llvm/clangd-format symlink setup" >&2
  install_status=1
fi
exit "$install_status"
