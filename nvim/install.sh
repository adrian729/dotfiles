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

# Neovim 0.12+: Homebrew when it can pour it, else the official release build
# (~/.local/opt/nvim, linked into ~/.local/bin ahead of an older brew nvim).
if ! nvim_ge_012; then
  if brew_can_pour neovim; then
    if brew list --formula neovim &>/dev/null; then
      brew upgrade neovim
    else
      brew install neovim
    fi
  fi
  hash -r
  nvim_ge_012 || prebuilt_install nvim
  hash -r
fi

for spec in lua-language-server marksman stylua rg:ripgrep ruff ty tree-sitter:tree-sitter-cli; do
  ensure_cmd "${spec%%:*}" "${spec#*:}" || install_status=1
done

# rustup puts a rust-analyzer proxy on PATH that fails until the component is
# added, so test that it runs rather than that it exists.
if ! rust-analyzer --version &>/dev/null; then
  if have rustup && rustup component add rust-analyzer &>/dev/null &&
    rust-analyzer --version &>/dev/null; then
    :
  else
    # Release build into ~/.local/bin, which is ahead of ~/.cargo/bin here.
    if brew_can_pour rust-analyzer; then
      brew install rust-analyzer
    else
      prebuilt_install rust-analyzer
    fi || install_status=1
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
  echo "WARNING: $(command -v nvim) is $(nvim --version | head -1); this config needs 0.12+." >&2
  install_status=1
fi

if command -v nvim &>/dev/null && nvim_ge_012; then
  echo "Installing Neovim plugins (lazy.nvim)..."
  # Plugins left in ~/.local/share/nvim/lazy by an older setup stay at their
  # old commits unless restored, and lazy records whatever is checked out
  # whenever it installs a missing plugin — so a plain first start would both
  # run stale plugins (nvim-treesitter before its rewrite) and write their
  # commits into the repo's lockfile. Install what is missing, put the
  # lockfile back, restore every plugin to it, and leave the lockfile as found.
  lockfile="$(dirname "$0")/.config/nvim/lazy-lock.json"
  saved_lock=$(mktemp "${TMPDIR:-/tmp}/lazy-lock.XXXXXX") && cp "$lockfile" "$saved_lock" || saved_lock=""
  nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1
  if [ -n "$saved_lock" ]; then
    cp "$saved_lock" "$lockfile"
    nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 || install_status=1
    cp "$saved_lock" "$lockfile"
    rm -f "$saved_lock"
  fi
  # nvim-treesitter stages each parser download in the cache and renames it
  # into place; one interrupted by an exiting nvim (the restores above start
  # downloads) leaves a directory the next rename cannot replace.
  rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/nvim/tree-sitter-"*
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
