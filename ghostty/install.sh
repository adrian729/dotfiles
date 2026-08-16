#!/bin/bash

. "$(dirname "$0")/../lib/common.sh"

brew_shellenv 2>/dev/null

# Ghostty reads ~/.config/ghostty/config on every platform, so only the install
# path differs. macOS gets the cask, which declares `depends_on macos: ">= 13"`
# and so cannot be reused on Linux.
#
# Linux has no single canonical source. Ghostty is an official package on Arch
# (extra), Alpine (testing), Gentoo, Void, Solus and NixOS, but Fedora has only
# a community COPR and Debian/Ubuntu have none at all — so ask the distro first
# and fall back in order of how closely each option tracks upstream:
#   1. the distro's own package, when it genuinely has one
#   2. the ghostty-ubuntu .deb, for the Debian family only (third-party, but
#      it repackages official releases)
#   3. the snap, which upstream builds from Ghostty's own scripts and which
#      works on any snapd distro
# Deliberately not attempted: enabling a third-party COPR on the user's behalf,
# and Flatpak — no Flathub package exists.
install_ghostty_linux() {
	if pkg_available ghostty; then
		info "Installing ghostty from the distro's repositories..."
		pkg_install ghostty && return 0
	fi

	if [ "$(pkg_mgr 2>/dev/null)" = apt-get ]; then
		info "ghostty is not in the archive — trying the ghostty-ubuntu .deb installer..."
		run_remote_installer https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh &&
			return 0
	fi

	if have snap; then
		info "Falling back to the ghostty snap..."
		sudo snap install ghostty --classic && return 0
	fi

	warn "could not install ghostty automatically — see https://ghostty.org/docs/install/binary"
	case "$(pkg_mgr 2>/dev/null)" in
	dnf | yum) warn "  on Fedora: sudo dnf copr enable scottames/ghostty && sudo dnf install ghostty" ;;
	esac
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
