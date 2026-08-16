#!/bin/bash
# Shared helpers for install.sh at the repo root and every package's install.sh.
#
# Sourced, never executed. Package scripts reach it via:
#   . "$(dirname "$0")/../lib/common.sh"
# and the root script via:
#   . "$(dirname "$0")/lib/common.sh"
#
# Homebrew is the primary package manager on both macOS and Linux, so almost
# every tool goes through `brew install`. apt is used only for the things that
# are inherently system integration and that brew either can't provide or
# shouldn't own: Homebrew's own build prerequisites, the display-server
# clipboard bridges, fontconfig, and the login shell.

# Guard against double-sourcing — nvim/install.sh sources clangd/install.sh,
# which sources this file too.
[ -n "${DOTFILES_COMMON_SH:-}" ] && return 0
DOTFILES_COMMON_SH=1

# ---------- platform ----------

case "$(uname -s)" in
	Darwin) DOTFILES_OS=macos ;;
	Linux) DOTFILES_OS=linux ;;
	*) DOTFILES_OS=unknown ;;
esac
export DOTFILES_OS

is_macos() { [ "$DOTFILES_OS" = macos ]; }
is_linux() { [ "$DOTFILES_OS" = linux ]; }

have() { command -v "$1" >/dev/null 2>&1; }

info() { echo "$*"; }
warn() { echo "⚠️  $*" >&2; }

# True when there is a human available to answer a prompt.
interactive() { [ -t 0 ] && [ -t 1 ]; }

# Ask a yes/no question. Non-interactive runs answer "no", so an unattended
# install never blocks on an unanswerable prompt.
confirm() {
	local ans
	interactive || return 1
	printf '%s [y/N] ' "$1"
	read -r ans || return 1
	case "$ans" in y | Y | yes | YES) return 0 ;; *) return 1 ;; esac
}

# ---------- apt (Linux only) ----------

_apt_updated=0

# apt_install PKG... — install Debian packages, refreshing the index once per
# *process*. Root install.sh runs each package installer as its own `bash`, so
# this dedupes calls within one script, not across a whole install run.
# Returns non-zero (without failing the caller's script) on a non-apt distro so
# callers can degrade to a warning.
apt_install() {
	is_linux || return 1
	have apt-get || {
		warn "no apt-get — install manually: $*"
		return 1
	}
	if [ "$_apt_updated" -eq 0 ]; then
		sudo apt-get update -qq || warn "apt-get update failed — continuing with a stale index"
		_apt_updated=1
	fi
	sudo apt-get install -y "$@"
}

# ---------- remote installers ----------

# run_remote_installer URL [ARG...] — download a remote install script, run it,
# and return its real exit status.
#
# The two obvious spellings both report success when the download fails, so a
# 404 or an offline machine reads as a completed install:
#   curl -fsSL URL | sh          → pipeline status is sh's, and sh with empty
#                                  input exits 0.
#   bash -c "$(curl -fsSL URL)"  → command substitution discards curl's status,
#                                  and `bash -c ""` exits 0.
# Downloading first is what makes `|| warn` mean anything.
run_remote_installer() {
	local url=$1 tmp rc
	shift
	tmp=$(mktemp "${TMPDIR:-/tmp}/remote-install.XXXXXX") || return 1
	if ! curl -fsSL "$url" -o "$tmp"; then
		rm -f "$tmp"
		warn "could not download $url"
		return 1
	fi
	# An error page or a truncated transfer is worse than no script at all.
	if [ ! -s "$tmp" ]; then
		rm -f "$tmp"
		warn "downloaded an empty script from $url"
		return 1
	fi
	bash "$tmp" "$@"
	rc=$?
	rm -f "$tmp"
	return "$rc"
}

# ---------- Homebrew ----------

# Absolute brew path for this machine, or empty. Homebrew is not on PATH during
# the run that installs it, so every caller resolves it through here rather than
# assuming `brew` is already callable.
brew_bin() {
	if have brew; then
		command -v brew
		return 0
	fi
	local p
	for p in /opt/homebrew/bin/brew /usr/local/bin/brew \
		/home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
		[ -x "$p" ] && {
			echo "$p"
			return 0
		}
	done
	return 1
}

# Put brew on PATH for the rest of this process.
brew_shellenv() {
	local b
	b=$(brew_bin) || return 1
	eval "$("$b" shellenv)"
}

# Install Homebrew if absent and leave it on PATH. Homebrew's own installer
# handles interactivity (it sets NONINTERACTIVE itself when stdin is not a TTY),
# but it does not install its Debian prerequisites — the list below is the one
# from Homebrew's docs, and without it the install fails on a fresh Kubuntu.
brew_bootstrap() {
	if brew_shellenv 2>/dev/null && have brew; then
		return 0
	fi

	if is_linux; then
		info "Installing Homebrew prerequisites (apt)..."
		apt_install build-essential procps curl file git ||
			warn "could not install Homebrew prerequisites — the installer below may fail"
	fi

	info "Installing Homebrew..."
	run_remote_installer https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh ||
		warn "the Homebrew installer did not complete"

	brew_shellenv 2>/dev/null
	have brew || {
		warn "Homebrew install failed"
		return 1
	}
}

# ensure_cmd COMMAND [FORMULA] — brew-install FORMULA (default: COMMAND) unless
# COMMAND already resolves. The command/formula split matters because several
# formulae are named differently from the binary they ship (rg/ripgrep).
ensure_cmd() {
	local cmd=$1 formula=${2:-$1}
	have "$cmd" && return 0
	have brew || {
		warn "$cmd missing and brew unavailable — install $formula manually"
		return 1
	}
	brew install "$formula"
}

# ---------- shared dependencies ----------

# A C toolchain + make, needed by nvim-treesitter's parser compilation and
# telescope-fzf-native's `make` build step.
ensure_build_tools() {
	if is_macos; then
		xcode-select -p >/dev/null 2>&1 && return 0
		warn "Xcode Command Line Tools missing — treesitter parsers and telescope-fzf-native will not build."
		warn "  Install them with: xcode-select --install"
		return 1
	fi
	have cc && have make && return 0
	info "Installing build toolchain (build-essential)..."
	apt_install build-essential || warn "no C toolchain — treesitter parsers will fail to compile"
}

# Clipboard bridge for the current display server. tmux-clipboard probes
# pbcopy → wl-copy → xclip → xsel at runtime and nvim's clipboard=unnamedplus
# needs one of them; macOS has pbcopy built in, Linux has nothing by default.
# Both Wayland and X11 helpers are installed because the session type at
# install time need not match the session the user ends up running.
ensure_clipboard() {
	is_macos && return 0
	if have wl-copy || have xclip || have xsel; then return 0; fi
	info "Installing clipboard bridges (wl-clipboard, xclip)..."
	apt_install wl-clipboard xclip ||
		warn "no clipboard tool — tmux copy and nvim's system clipboard will silently do nothing"
}

# starship.toml, `eza --icons`, lf's icons file and the tmux status bar all
# render Nerd Font glyphs. Without a patched font every one of them shows tofu.
# The Nerd Font build of Fira Code also covers kitty.conf's plain "Fira Code"
# family via the terminals' own per-glyph font fallback.
ensure_nerd_font() {
	local zip dir tmpdir rc

	# fc-list is the reliable check where it exists; macOS usually has no
	# fontconfig, so fall back to looking in the font directories themselves.
	if have fc-list && fc-list 2>/dev/null | grep -qi "FiraCode Nerd Font"; then
		return 0
	fi
	# Both layouts have to be checked: the cask drops the .ttf files straight
	# into fontdir, while the zip fallback below nests them in a subdirectory.
	if ls "$HOME/Library/Fonts"/FiraCodeNerdFont* >/dev/null 2>&1 ||
		ls /Library/Fonts/FiraCodeNerdFont* >/dev/null 2>&1 ||
		ls "$HOME/.local/share/fonts"/FiraCodeNerdFont* >/dev/null 2>&1 ||
		ls "$HOME/.local/share/fonts"/*/FiraCodeNerdFont* >/dev/null 2>&1; then
		return 0
	fi

	# One path for both platforms: the font-fira-code-nerd-font cask declares no
	# macOS dependency, and Homebrew's Linux cask config sets fontdir to
	# ~/.local/share/fonts, so the cask installs correctly on Linux too.
	if have brew; then
		info "Installing FiraCode Nerd Font..."
		if brew install --cask font-fira-code-nerd-font; then
			have fc-cache && fc-cache -f >/dev/null 2>&1
			return 0
		fi
		warn "cask install failed — falling back to the nerd-fonts release"
	fi

	# Fallback for a machine where the Homebrew bootstrap did not succeed.
	is_linux || {
		warn "install FiraCode Nerd Font manually — icons will render as tofu"
		return 1
	}
	have unzip || apt_install unzip || {
		warn "unzip missing — cannot install FiraCode Nerd Font"
		return 1
	}
	have fc-cache || apt_install fontconfig || warn "fontconfig missing — font cache will not refresh"

	dir="$HOME/.local/share/fonts/FiraCodeNerdFont"
	# A temp *directory*, not `mktemp <tmpl>.zip`: both BSD and GNU mktemp only
	# substitute Xs that end the template, so a ".zip" suffix would yield the
	# literal, guessable path /tmp/FiraCode.XXXXXX.zip.
	tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/firacode.XXXXXX") || return 1
	zip="$tmpdir/FiraCode.zip"
	rc=0
	if curl -fsSL -o "$zip" \
		https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip; then
		mkdir -p "$dir"
		unzip -oq "$zip" -x 'README*' 'LICENSE*' -d "$dir" || rc=1
		[ "$rc" -eq 0 ] && have fc-cache && fc-cache -f "$dir" >/dev/null 2>&1
	else
		warn "could not download FiraCode Nerd Font — icons will render as tofu"
		rc=1
	fi
	# Report the real outcome: `rm -rf` as the last statement would otherwise
	# make a failed download return 0, contradicting the branches above.
	rm -rf "$tmpdir"
	return "$rc"
}

# npm, for the globally-installed CLIs (claude-agent-acp). nvm owns node on both
# platforms so there is one node version manager rather than a brew node racing
# an nvm node on PATH. Callers must not assume the interactive shell's lazy nvm
# shim exists — this runs in non-interactive bash where .zshrc never loaded.
ensure_node() {
	export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

	# nvm is installed even when some other npm already happens to be on PATH:
	# .zshrc defines lazy nvm/node/npm shims that source $NVM_DIR/nvm.sh, so a
	# machine without nvm leaves those shims inert. Returning early on `have npm`
	# would skip this, because brew's `opencode` formula depends on node and so
	# drops an npm on PATH before this ever runs.
	if [ ! -s "$NVM_DIR/nvm.sh" ]; then
		info "Installing nvm..."
		run_remote_installer https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh ||
			warn "nvm install failed"
	fi

	# An npm already on PATH (brew's node, pulled in by opencode) is enough for
	# the global installs this gates — no need to source nvm or build a second
	# node on top of it.
	have npm && return 0

	[ -s "$NVM_DIR/nvm.sh" ] || return 1
	# shellcheck disable=SC1091
	. "$NVM_DIR/nvm.sh" || return 1
	have npm && return 0

	info "Installing the latest LTS node (nvm)..."
	nvm install --lts >/dev/null 2>&1 || {
		warn "node install failed"
		return 1
	}
	have npm
}
