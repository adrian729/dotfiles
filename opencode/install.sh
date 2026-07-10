#!/bin/bash
config_target="$HOME/.config/opencode/opencode.json"
[ -L "$config_target" ] && rm "$config_target"
mkdir -p "$(dirname "$config_target")"
/bin/cp "$(dirname "$0")/.config/opencode/opencode.json" "$config_target"
