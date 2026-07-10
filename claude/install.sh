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

# Probe this machine's local-LLM (ollama) capability and record the per-machine
# policy for Claude/the `llm` wrapper. Run by explicit path, not bare name:
# ~/.local/scripts is only on PATH via zshrc (never sourced by this installer),
# and this script runs even if the user declined stowing `claude`, so the
# symlink may not exist yet. Non-fatal in every case — install proceeds.
probe="$HOME/.local/scripts/llm-probe"
if [ -x "$probe" ]; then
    "$probe" || echo "llm-probe ran but failed — skipping local-LLM capability check"
else
    echo "llm-probe not stowed yet — skipping local-LLM capability check"
fi

# Copy settings.json as a regular file (not symlink), so Claude Code can
# modify it freely without dirtying the dotfiles repo.  Re-run install.sh
# to reset from the repo version.
settings_target="$HOME/.claude/settings.json"
[ -L "$settings_target" ] && rm "$settings_target"
mkdir -p "$(dirname "$settings_target")"
/bin/cp "$(dirname "$0")/.claude/settings.json" "$settings_target"

