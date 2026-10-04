#!/bin/bash

. "$(dirname "$0")/../lib/common.sh"

brew_shellenv 2>/dev/null

ensure_cmd jq

# The opencode formula has x86_64_linux/arm64_linux bottles, so brew covers both
# platforms; fall back to opencode's own installer if brew never came up.
if ! have opencode; then
	ensure_cmd opencode ||
		run_remote_installer https://opencode.ai/install ||
		warn "opencode install failed — see https://opencode.ai/docs"
fi

config_target="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json"
config_dir=$(dirname "$config_target")
# Old folded Stow links must be removed before any copied config is written.
if [ -L "${XDG_CONFIG_HOME:-$HOME/.config}" ] || [ -L "$config_dir" ]; then
    warn "OpenCode config directory is symlinked; unstow and restow with --no-folding first"
    exit 1
fi
mkdir -p "$config_dir" || exit 1
tmp_config=$(mktemp "$config_target.XXXXXX") || exit 1
trap 'rm -f "$tmp_config" "${tmp_merged:-}"' EXIT
model_config="$(dirname "$0")/.local/config/opencode-models.json"
# Always install explicit free pins, even offline or before scripts are stowed.
# Retired pins fail visibly instead of inheriting an ambient paid model.
if ! jq --slurpfile models "$model_config" '
    $models[0] as $cfg |
    ([$cfg.agents | to_entries[] | .key as $name |
      ([.value[] | select(. as $m | $cfg.free_models | index($m))][0]) as $pick |
      if $pick == null then error("no configured free model for " + $name)
      else {key: $name, value: {model: $pick}} end] | from_entries) as $pins |
    .agent = ((.agent // {}) * $pins) |
    .small_model = ($pins.relay.model // error("missing relay pin"))
' "$(dirname "$0")/.config/opencode/opencode.json" > "$tmp_config"; then
    warn "could not prepare OpenCode settings; existing config left untouched"
    exit 1
fi

probe="$HOME/.local/scripts/opencode-llm-probe"
if [ -x "$probe" ]; then
    "$probe" || warn "relay catalog could not be verified; keeping configured free candidates"
fi
probe_agent="$HOME/.local/scripts/opencode-agent-models-probe"
if [ -x "$probe_agent" ] && "$probe_agent"; then
    overrides="$HOME/.local/state/agents/opencode-agent-model-overrides.json"
    tmp_merged=$(mktemp "$config_target.XXXXXX") || exit 1
    # Only accept complete free pins from this successful probe invocation.
    if jq -e --slurpfile pins "$overrides" --slurpfile models "$model_config" '
        $models[0] as $cfg | $pins[0].agent as $agents |
        if all($cfg.agents | keys[]; . as $name |
            ($agents[$name].model as $m | $cfg.free_models | index($m)) != null)
        then .agent *= $agents | .small_model = $agents.relay.model
        else error("incomplete or non-free probe result") end
    ' "$tmp_config" > "$tmp_merged"; then
        mv "$tmp_merged" "$tmp_config" || exit 1
    else
        warn "model overrides invalid; keeping explicit configured free pins"
    fi
else
    warn "agent catalog not verified; installed free pins may need a model-list refresh"
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
