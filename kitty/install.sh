#!/bin/bash

. "$(dirname "$0")/../lib/common.sh"

brew_shellenv 2>/dev/null

# Homebrew carries kitty only as a cask (no formula), and that cask declares
# `depends_on macos: ">= 12"`, so `brew install --cask kitty` on Linux fails
# with "This cask requires macOS" (Homebrew does install Linux-supporting
# casks, just not this one). kitty does ship its own Linux builds, but rather
# than bolt those on, this package is
# macOS-only by choice: ghostty is the Linux daily driver. The root install.sh
# lists kitty in its `macos_only` array and never gets this far on Linux — this
# guard is the second line of defence for a direct `bash kitty/install.sh`.
is_macos || {
	info "kitty package is macOS-only here (ghostty is the Linux terminal), skipping"
	exit 0
}

if have brew; then
	# `brew --prefix` errors when brew is missing, which would make the -d test
	# read as "already installed" and silently skip the install.
	[ -d "$(brew --prefix)/Caskroom/kitty" ] || brew install --cask kitty
else
	warn "brew unavailable — install kitty manually"
fi

# kitty.conf asks for the plain "Fira Code" family; the Nerd Font build
# supplies the glyphs starship/eza/lf/tmux need via kitty's font fallback.
ensure_nerd_font
