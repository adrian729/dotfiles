#!/bin/bash

. "$(dirname "$0")/../lib/common.sh"

brew_shellenv 2>/dev/null

if ! have codex; then
	ensure_cmd codex ||
		run_remote_installer https://chatgpt.com/codex/install.sh ||
		warn "Codex install failed — see https://learn.chatgpt.com/docs/codex/cli"
fi

config_target="${CODEX_HOME:-$HOME/.codex}/config.toml"
mkdir -p "$(dirname "$config_target")" || exit 1
tmp_config=$(mktemp "$config_target.XXXXXX") || exit 1
if /bin/cp "$(dirname "$0")/.codex/config.toml" "$tmp_config" &&
	chmod 600 "$tmp_config" &&
	mv -f "$tmp_config" "$config_target"; then
	info "Copied Codex settings to $config_target"
else
	rm -f "$tmp_config"
	warn "failed to copy config.toml — leaving existing $config_target untouched"
	exit 1
fi
