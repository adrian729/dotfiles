#!/bin/bash

# Claude Code preferences that live in ~/.claude.json (not suitable for stow)
CLAUDE_JSON="$HOME/.claude.json"

if [ -f "$CLAUDE_JSON" ]; then
    echo "Setting vim mode in $CLAUDE_JSON..."
    jq '.editorMode = "vim"' "$CLAUDE_JSON" > /tmp/claude.json.tmp && mv /tmp/claude.json.tmp "$CLAUDE_JSON"
    echo "Done."
else
    echo "~/.claude.json not found, skipping (run claude once first)."
fi
