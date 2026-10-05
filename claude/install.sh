#!/bin/bash

. "$(dirname "$0")/../lib/common.sh"

brew_shellenv 2>/dev/null

ensure_cmd jq

# Recognize an existing native install even before the login shell adds its PATH.
if ! have claude && [ -x "$HOME/.local/bin/claude" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# The claude-code cask does now ship arm64_linux/x86_64_linux variants, but
# Linux still goes through the official installer (drops the binary in
# ~/.local/bin): it is Anthropic's documented Linux path and self-updates,
# whereas the cask would pin upgrades to `brew upgrade`.
if is_macos; then
	install_claude() { brew install --cask claude-code@latest; }
	reinstall_claude() { brew reinstall --cask claude-code@latest; }
	claude_install_desc="Homebrew"
else
	install_claude() { run_remote_installer https://claude.ai/install.sh; }
	reinstall_claude() { install_claude; }
	claude_install_desc="claude.ai/install.sh"
fi

if ! command -v claude &>/dev/null; then
	echo "Installing Claude Code CLI via $claude_install_desc..."
	install_claude || warn "Claude Code installation failed"
else
	# A working npm install or wrapper need not be a native executable.
	if ! claude --version >/dev/null 2>&1; then
		echo "claude --version failed — reinstalling via $claude_install_desc..."
		reinstall_claude || warn "Claude Code reinstallation failed"
	fi
fi
# Make the fresh native install available to the plugin setup below.
if ! have claude && [ -x "$HOME/.local/bin/claude" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# nvim's claude_code ACP adapter execs `claude-agent-acp` directly, so without it
# every ACP chat and inline request dies at spawn with ENOENT. npm-only: there is
# no brew formula, and neither the cask nor claude.ai/install.sh bundles it.
#
# The package requires node 22+; ensure_node brings an older nvm setup up to
# the current LTS rather than letting npm install it on an unsupported node.
if ! command -v claude-agent-acp &>/dev/null; then
	if ensure_node 22; then
		echo "Installing claude-agent-acp (ACP bridge for nvim)..."
		npm install -g @agentclientprotocol/claude-agent-acp ||
			echo "claude/install.sh: claude-agent-acp install failed — nvim ACP chat and inline will not work" >&2
	else
		echo "claude/install.sh: npm unavailable — skipping claude-agent-acp; nvim ACP chat and inline will not work until it is installed" >&2
	fi
fi

# nvim's opencode chat adapter and its inline relay both shell out to `opencode`.
command -v opencode &>/dev/null ||
	echo "claude/install.sh: opencode not on PATH — nvim's opencode chat and inline relay will not work (see opencode/install.sh)" >&2

CLAUDE_JSON="$HOME/.claude.json"

if [ -f "$CLAUDE_JSON" ]; then
    echo "Setting vim mode in $CLAUDE_JSON..."
    tmp_json=""
    if tmp_json=$(mktemp "$CLAUDE_JSON.XXXXXX") &&
        jq '.editorMode = "vim"' "$CLAUDE_JSON" > "$tmp_json" &&
        chmod 600 "$tmp_json" && mv "$tmp_json" "$CLAUDE_JSON"; then
        echo "Done."
    else
        rm -f "$tmp_json"
        echo "claude/install.sh: failed to set editorMode in $CLAUDE_JSON — leaving it untouched" >&2
    fi
else
    echo "~/.claude.json not found, skipping (run claude once first)."
fi

# Probe this machine's local-LLM (ollama) model availability and filter the
# catalog against what's actually pulled. Runs before llm-probe, which reads
# the filtered catalog. Non-fatal in every case.
probe="$HOME/.local/scripts/llm-models-probe"
if [ -x "$probe" ]; then
    "$probe" || warn "llm-models-probe failed — existing model state may be stale"
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
# to reset from the repo version — except the model and effort picked with
# /model, which are this machine's choice and which the repo does not set.
settings_target="$HOME/.claude/settings.json"
settings_source="$(dirname "$0")/.claude/settings.json"
tmp_settings=""
copy_settings() {
    # Without jq nothing can be merged; the repo copy alone still works.
    have jq || { cat "$settings_source"; return; }
    jq -e . "$settings_source" >/dev/null 2>&1 || return 1
    if jq -e 'type == "object"' "$settings_target" >/dev/null 2>&1; then
        jq -s '.[1] + (.[0] | {model, modelSettings, effortLevel}
            | with_entries(select(.value != null)))' "$settings_target" "$settings_source"
    else
        cat "$settings_source"
    fi
}
if ! { mkdir -p "$(dirname "$settings_target")" &&
    tmp_settings=$(mktemp "$settings_target.XXXXXX") &&
    copy_settings > "$tmp_settings" &&
    chmod 644 "$tmp_settings" && mv "$tmp_settings" "$settings_target"; }; then
    rm -f "$tmp_settings"
    echo "claude/install.sh: failed to copy settings.json — leaving existing $settings_target untouched" >&2
fi

# The official marketplace has no ty plugin, so ty-lsp lives in this repo's own
# marketplace. Registered via the CLI rather than extraKnownMarketplaces in the
# repo settings.json because the directory source must be an absolute path,
# which differs per machine; it has to run after the copy above, since `add`
# writes that declaration into ~/.claude/settings.json. Safe to re-run.
#
# install copies the plugin into ~/.claude/plugins/cache and never refreshes it:
# `claude plugin update` is gated on the version field, so after editing
# marketplace/plugins/ty-lsp either bump its version or uninstall and reinstall.
if command -v claude &>/dev/null; then
    marketplace="$(cd "$(dirname "$0")/marketplace" && pwd)"
    claude plugin marketplace add "$marketplace" >/dev/null &&
        claude plugin install ty-lsp@dotfiles >/dev/null ||
        echo "claude/install.sh: failed to install ty-lsp plugin — Claude Code will have no Python LSP" >&2
fi
