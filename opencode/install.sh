#!/bin/bash

command -v jq &>/dev/null || brew install jq

command -v opencode &>/dev/null || brew install opencode
command -v fzf &>/dev/null || brew install fzf

config_target="$HOME/.config/opencode/opencode.json"
mkdir -p "$(dirname "$config_target")"
tmp_config=$(mktemp "$config_target.XXXXXX")
if /bin/cp "$(dirname "$0")/.config/opencode/opencode.json" "$tmp_config"; then
    chmod 644 "$tmp_config"
    mv "$tmp_config" "$config_target"
else
    rm -f "$tmp_config"
    echo "opencode/install.sh: failed to copy opencode.json — leaving existing $config_target untouched" >&2
fi

# Probe opencode's free-tier model availability and record the per-machine
# filtered list for the opencode-llm script. Non-fatal.
probe="$HOME/.local/scripts/opencode-llm-probe"
if [ -x "$probe" ]; then
    "$probe" || echo "opencode-llm-probe failed — using default model list"
else
    echo "opencode-llm-probe not stowed yet — skipping"
fi

# Probe available models and assign per-agent model overrides.
# Merges into the copied opencode.json so the Markdown agent defaults get
# upgraded to the best available free model per agent. Non-fatal.
probe_agent="$HOME/.local/scripts/opencode-agent-models-probe"
if [ -x "$probe_agent" ]; then
    "$probe_agent" || echo "opencode-agent-models-probe failed — using Markdown defaults"
    overrides="$HOME/.local/state/agents/opencode-agent-model-overrides.json"
    if [ -f "$overrides" ] && command -v jq >/dev/null 2>&1 && jq -e '.agent != null' "$overrides" >/dev/null 2>&1; then
        tmp_merged=$(mktemp "$config_target.XXXXXX")
        if jq -s '.[0] * .[1]' "$config_target" "$overrides" > "$tmp_merged"; then
            chmod 644 "$tmp_merged"
            mv "$tmp_merged" "$config_target"
        else
            rm -f "$tmp_merged"
        fi
    fi
else
    echo "opencode-agent-models-probe not stowed yet — skipping"
fi
