#!/bin/bash

. "$(dirname "$0")/../lib/common.sh"

brew_shellenv 2>/dev/null

# macOS goes through brew. On Linux the official installer is the better
# source: it registers the ollama systemd unit and pulls the CUDA/ROCm runtime
# libraries, neither of which the Homebrew build sets up.
if ! have ollama; then
	if is_macos; then
		ensure_cmd ollama
	elif is_linux; then
		info "Installing ollama (official installer — sets up the systemd service)..."
		run_remote_installer https://ollama.com/install.sh ||
			warn "ollama install failed — see https://ollama.com/download/linux"
	else
		warn "unsupported platform ($(uname -s)) — skipping ollama"
	fi
fi

# ollama-ctl and tmux-ollama-status format RSS with bc.
ensure_cmd bc
ensure_cmd jq

ENV_FILE="$HOME/.config/ollama/ollama.env"
TEMPLATE_FILE="$HOME/.config/ollama/ollama.env.template"

if [ ! -f "$ENV_FILE" ]; then
	echo "⚠️  $ENV_FILE not found (only the template is present)."
	echo "   Run: cp $TEMPLATE_FILE $ENV_FILE"
	echo "   Then edit it and paste your OLLAMA_API_KEY."
fi
