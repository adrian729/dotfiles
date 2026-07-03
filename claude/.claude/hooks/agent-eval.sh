#!/usr/bin/env bash
# UserPromptSubmit hook: one-line nudge to route delegated tasks through the
# custom agents. Descriptions are already injected into context by the harness,
# so no need to re-list them — routing is advisory (~80-90% with sharp
# descriptions) and this reminder closes part of the gap. Fires every prompt
# because delegation can happen any turn; exits quietly while ~/.claude/agents
# isn't stowed yet.

AGENTS_DIR="$(dirname "$0")/../agents"
ls "$AGENTS_DIR"/*.md >/dev/null 2>&1 || exit 0

echo 'Route subagent tasks through the matching custom agent, not general-purpose; pass a call-time model only to effort-* carriers.'
