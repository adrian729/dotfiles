#!/bin/bash

. "$(dirname "$0")/../lib/common.sh"

brew_shellenv 2>/dev/null

# macOS: the Homebrew formula, run as a `brew services` daemon, where it can be
# poured; otherwise (Intel Macs get no bottles) the official app through its
# cask, which runs the server from the menu bar and links the `ollama` CLI.
# ollama-ctl manages either. On Linux the official installer is the better
# source: it registers the ollama systemd unit and pulls the CUDA/ROCm runtime
# libraries, neither of which the Homebrew build sets up.
if ! have ollama; then
	if is_macos; then
		if brew_can_pour ollama; then
			brew install ollama || exit 1
		else
			ensure_cask ollama-app Ollama.app || exit 1
			hash -r
			# The cask links the CLI; an app installed by hand does not.
			for app in /Applications/Ollama.app "$HOME/Applications/Ollama.app"; do
				have ollama && break
				[ -x "$app/Contents/Resources/ollama" ] && mkdir -p "$LOCAL_BIN" &&
					ln -sfn "$app/Contents/Resources/ollama" "$LOCAL_BIN/ollama"
			done
		fi
	elif is_linux; then
		info "Installing ollama (official installer — sets up the systemd service)..."
		run_remote_installer https://ollama.com/install.sh || {
			warn "ollama install failed — see https://ollama.com/download/linux"
			exit 1
		}
	else
		warn "unsupported platform ($(uname -s)) — skipping ollama"
		exit 1
	fi
fi

ensure_cmd jq || exit 1
ensure_cmd curl || exit 1

ENV_FILE="$HOME/.config/ollama/ollama.env"
TEMPLATE_FILE="$HOME/.config/ollama/ollama.env.template"

if [ ! -f "$ENV_FILE" ]; then
	info "Local Ollama needs no API key. Optional shell environment template: $TEMPLATE_FILE"
fi
