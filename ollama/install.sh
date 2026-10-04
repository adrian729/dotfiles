#!/bin/bash

. "$(dirname "$0")/../lib/common.sh"

brew_shellenv 2>/dev/null

# macOS goes through brew. On Linux the official installer is the better
# source: it registers the ollama systemd unit and pulls the CUDA/ROCm runtime
# libraries, neither of which the Homebrew build sets up.
if ! have ollama; then
	if is_macos; then
		ensure_cmd ollama || exit 1
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
