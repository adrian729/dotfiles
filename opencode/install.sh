#!/bin/bash

. "$(dirname "$0")/../lib/common.sh"

brew_shellenv 2>/dev/null

ensure_cmd jq

# A bottle where Homebrew has one, else opencode's own installer (into
# ~/.opencode/bin, already on the dotfiles PATH) — never a source build, which
# needs bun, zig and rust.
ensure_cmd opencode || warn "opencode install failed — see https://opencode.ai/docs"

config_target="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json"
config_dir=$(dirname "$config_target")
# Old folded Stow links must be removed before any copied config is written.
if [ -L "${XDG_CONFIG_HOME:-$HOME/.config}" ] || [ -L "$config_dir" ]; then
    warn "OpenCode config directory is symlinked; unstow and restow with --no-folding first"
    exit 1
fi
mkdir -p "$config_dir" || exit 1
tmp_config=$(mktemp "$config_target.XXXXXX") || exit 1
trap 'rm -f "$tmp_config"' EXIT
if ! jq . "$(dirname "$0")/.config/opencode/opencode.json" > "$tmp_config"; then
    warn "could not prepare OpenCode settings; existing config left untouched"
    exit 1
fi
chmod 600 "$tmp_config" && mv "$tmp_config" "$config_target" || exit 1

# Sync provider.ollama.models in the copied opencode.json with whatever's
# actually pulled in the local Ollama daemon right now (live query, not a
# static list). A failed query preserves the current map; a successful empty catalog clears it. Same script is meant to be re-run manually after
# `ollama pull`/`ollama rm` — see opencode-ollama-models-sync.
sync_ollama="$HOME/.local/scripts/opencode-ollama-models-sync"
if [ -x "$sync_ollama" ]; then
    "$sync_ollama" || echo "opencode-ollama-models-sync failed — leaving provider.ollama.models as-is"
else
    echo "opencode-ollama-models-sync not stowed yet — skipping"
fi
