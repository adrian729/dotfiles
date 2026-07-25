#!/bin/bash

command -v jq &>/dev/null || brew install jq

# Homebrew ships claude-code as a cask, which Linuxbrew does not support, so
# Linux goes through the official installer (drops the binary in ~/.local/bin).
if [ "$(uname)" = Darwin ]; then
	claude_native_fmt="Mach-O"
	install_claude() { brew install --cask claude-code@latest; }
	reinstall_claude() { brew reinstall --cask claude-code@latest; }
	claude_install_desc="Homebrew"
else
	claude_native_fmt="ELF"
	install_claude() { curl -fsSL https://claude.ai/install.sh | bash; }
	reinstall_claude() { install_claude; }
	claude_install_desc="claude.ai/install.sh"
fi

if ! command -v claude &>/dev/null; then
	echo "Installing Claude Code CLI via $claude_install_desc..."
	install_claude
else
	# Verify binary is a real native executable, not a stub (e.g. from failed
	# npm postinstall). -L so a symlinked binary reports the target's format.
	if ! file -L "$(command -v claude)" 2>/dev/null | grep -q "$claude_native_fmt"; then
		echo "claude binary is a stub — reinstalling via $claude_install_desc..."
		reinstall_claude
	fi
fi

CLAUDE_JSON="$HOME/.claude.json"

if [ -f "$CLAUDE_JSON" ]; then
    echo "Setting vim mode in $CLAUDE_JSON..."
    tmp_json=$(mktemp "$CLAUDE_JSON.XXXXXX")
    if jq '.editorMode = "vim"' "$CLAUDE_JSON" > "$tmp_json"; then
        chmod 644 "$tmp_json"
        mv "$tmp_json" "$CLAUDE_JSON"
    else
        rm -f "$tmp_json"
        echo "claude/install.sh: failed to set editorMode in $CLAUDE_JSON — leaving it untouched" >&2
    fi
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
mkdir -p "$(dirname "$settings_target")"
tmp_settings=$(mktemp "$settings_target.XXXXXX")
if /bin/cp "$(dirname "$0")/.claude/settings.json" "$tmp_settings"; then
    chmod 644 "$tmp_settings"
    mv "$tmp_settings" "$settings_target"
else
    rm -f "$tmp_settings"
    echo "claude/install.sh: failed to copy settings.json — leaving existing $settings_target untouched" >&2
fi

