#!/bin/bash
config_target="$HOME/.config/opencode/opencode.json"
[ -L "$config_target" ] && rm "$config_target"
mkdir -p "$(dirname "$config_target")"
/bin/cp "$(dirname "$0")/.config/opencode/opencode.json" "$config_target"

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
# upgraded to the best available model per tier. Non-fatal.
probe_agent="$HOME/.local/scripts/opencode-agent-models-probe"
if [ -x "$probe_agent" ]; then
    "$probe_agent" || echo "opencode-agent-models-probe failed — using Markdown defaults"
    overrides="$HOME/.local/state/agents/opencode-agent-model-overrides.json"
    if [ -f "$overrides" ] && command -v jq >/dev/null 2>&1; then
        jq -s '.[0] * .[1]' "$config_target" "$overrides" > "$config_target.tmp" \
          && mv "$config_target.tmp" "$config_target"
    fi
else
    echo "opencode-agent-models-probe not stowed yet — skipping"
fi
