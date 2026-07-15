#!/bin/bash

command -v jq &>/dev/null || brew install jq

if ! command -v claude &>/dev/null; then
	echo "Installing Claude Code CLI..."
	npm install -g @anthropic-ai/claude-code
fi

CLAUDE_JSON="$HOME/.claude.json"

if [ -f "$CLAUDE_JSON" ]; then
    echo "Setting vim mode in $CLAUDE_JSON..."
    jq '.editorMode = "vim"' "$CLAUDE_JSON" > /tmp/claude.json.tmp && mv /tmp/claude.json.tmp "$CLAUDE_JSON"
    echo "Done."
else
    echo "~/.claude.json not found, skipping (run claude once first)."
fi

# Probe this machine's local-LLM (ollama) model availability and filter the
# catalog against what's actually pulled. Runs before llm-probe, which reads
# the filtered catalog. Non-fatal in every case.
probe="$HOME/.local/scripts/llm-models-probe"
if [ -x "$probe" ]; then
    "$probe" || echo "llm-models-probe failed — using static catalog"
else
    echo "llm-models-probe not stowed yet — skipping"
fi

# Probe this machine's local-LLM (ollama) capability and record the per-machine
# policy for Claude/the `llm` wrapper. Reads the model catalog from the state
# file written by llm-models-probe above (or falls back to static config).
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

