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
