#!/bin/bash

. "$(dirname "$0")/../lib/common.sh"

brew_shellenv 2>/dev/null

ensure_cmd codex ||
	{ warn "Codex install failed — see https://learn.chatgpt.com/docs/codex/cli"; exit 1; }

# merge_config.py needs tomllib (Python 3.11+). macOS ships 3.9, so use a
# poured Homebrew python, or else a uv-managed build of 3.13.
config_python=(python3)
if ! python3 -c 'import tomllib' 2>/dev/null; then
	if brew_can_pour python && brew install python; then
		config_python=("$(brew --prefix python)/bin/python3")
	elif ensure_uv; then
		config_python=(uv run --quiet --no-project --python 3.13 python)
	fi
	if ! "${config_python[@]}" -c 'import tomllib' 2>/dev/null; then
		warn "Codex config installation requires Python 3.11+"
		exit 1
	fi
fi

config_target="${CODEX_HOME:-$HOME/.codex}/config.toml"
if "${config_python[@]}" "$(dirname "$0")/merge_config.py" "$(dirname "$0")/.codex/config.toml" "$config_target"; then
	info "Applied Codex defaults to $config_target; kept local integrations"
else
	warn "failed to install config.toml — leaving existing $config_target untouched"
	exit 1
fi

ensure_cmd shellcheck || warn "ShellCheck unavailable — shell diagnostics will be limited"

bash "$(dirname "$0")/install_playwright.sh" || warn "Playwright setup incomplete; see the messages above"
