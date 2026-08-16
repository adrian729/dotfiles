#!/bin/bash

. "$(dirname "$0")/../lib/common.sh"

brew_shellenv 2>/dev/null

# Ghostty reads ~/.config/ghostty/config on both platforms, so only the install
# path differs. macOS gets the cask — which declares `depends_on macos: ">= 13"`
# and so cannot be reused on Linux. Linux has no single canonical source, so
# try the packaged options in order of how well they track upstream:
#   1. apt      — in the Ubuntu archive from 26.04 on, but can lag releases.
#   2. .deb     — ghostty-ubuntu builds official releases for Ubuntu/Debian.
#   3. snap     — built from Ghostty's own scripts; works on any snapd distro.
install_ghostty_linux() {
	if apt-cache show ghostty >/dev/null 2>&1; then
		apt_install ghostty && return 0
	fi

	info "ghostty not in the apt archive — trying the ghostty-ubuntu .deb installer..."
	if run_remote_installer https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh; then
		return 0
	fi

	if have snap; then
		info "Falling back to the ghostty snap..."
		sudo snap install ghostty --classic && return 0
	fi

	warn "could not install ghostty — see https://ghostty.org/docs/install/binary"
	return 1
}

if is_macos; then
	# `brew --prefix` is only safe once brew is known to exist; on a failed
	# bootstrap it errors out and the -d test would silently read as "missing".
	if have brew; then
		[ -d "$(brew --prefix)/Caskroom/ghostty" ] || brew install --cask ghostty
	else
		warn "brew unavailable — install ghostty manually"
	fi
elif is_linux; then
	have ghostty || install_ghostty_linux
else
	warn "unsupported platform ($(uname -s)) — skipping ghostty"
fi

# Ghostty bundles Nerd Font symbol fallback, but the shell prompt, eza, lf and
# tmux all render glyphs outside that set too.
ensure_nerd_font
