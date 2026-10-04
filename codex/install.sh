#!/bin/bash

. "$(dirname "$0")/../lib/common.sh"

brew_shellenv 2>/dev/null

if ! have codex; then
	ensure_cmd codex ||
		run_remote_installer https://chatgpt.com/codex/install.sh ||
		{ warn "Codex install failed — see https://learn.chatgpt.com/docs/codex/cli"; exit 1; }
fi

config_python=python3
if ! "$config_python" -c 'import tomllib' 2>/dev/null; then
	if have brew && brew install python; then
		config_python="$(brew --prefix python)/bin/python3"
	fi
	if ! "$config_python" -c 'import tomllib' 2>/dev/null; then
		warn "Codex config installation requires Python 3.11+ (install or upgrade the Homebrew python formula)"
		exit 1
	fi
fi

config_target="${CODEX_HOME:-$HOME/.codex}/config.toml"
if "$config_python" "$(dirname "$0")/merge_config.py" "$(dirname "$0")/.codex/config.toml" "$config_target"; then
	info "Applied Codex defaults to $config_target; kept local integrations"
else
	warn "failed to install config.toml — leaving existing $config_target untouched"
	exit 1
fi

ensure_cmd shellcheck || warn "ShellCheck unavailable — shell diagnostics will be limited"

bash "$(dirname "$0")/install_playwright.sh" || warn "Playwright setup incomplete; see the messages above"
