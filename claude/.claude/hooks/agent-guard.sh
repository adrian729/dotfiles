#!/usr/bin/env bash
# PreToolUse hook (matcher: Agent|Task): enforce pinned models on custom agents.
# The Agent tool's call-time `model` param silently overrides frontmatter, so a
# spawn that passes `model` bypasses the per-role tiers. Block those — except on
# effort-* carriers, where passing a model is the intended use (any model × any
# pinned effort). Blocking = exit 2; stderr is fed back so the retry self-corrects.

command -v jq >/dev/null 2>&1 || exit 0  # no jq → fail open, never break spawns

AGENTS_DIR="$(dirname "$0")/../agents"

input=$(cat)
model=$(printf '%s' "$input" | jq -r '.tool_input.model // empty' 2>/dev/null)
agent=$(printf '%s' "$input" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null)

# No model override → the agent's frontmatter tier applies. Nothing to enforce.
[ -z "$model" ] && exit 0

# Agent names are file stems under $AGENTS_DIR — reject anything that could escape it
# (path separators, '..') before ever using $agent to build a path.
case "$agent" in
    ''|*[!A-Za-z0-9_-]*) exit 0 ;;
esac

# Effort carriers exist precisely to combine a caller-chosen model with a pinned effort.
case "$agent" in
    effort-*) exit 0 ;;
esac

# Only enforce the user definitions this hook manages. Project definitions
# take precedence. Unknown names and unpinned agents are outside this guard's
# scope. The hook payload does not identify same-name CLI overrides.
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
case "$cwd" in /*) ;; *) cwd="" ;; esac
while [ -n "$cwd" ] && [ "$cwd" != / ]; do
    [ -f "$cwd/.claude/agents/$agent.md" ] && exit 0
    cwd=$(dirname "$cwd")
done
[ -f "$AGENTS_DIR/$agent.md" ] || exit 0
pin=$(awk '/^---$/ {n++; next} n == 1 && /^model:/ {sub(/^model: */, ""); print; exit}' "$AGENTS_DIR/$agent.md")
case "$pin" in ''|inherit|"$model") exit 0 ;; esac

echo "Blocked: the call-time 'model' param would override the pinned model of '${agent:-<unset>}'. Retry without 'model' to use the agent's tier — or, if the user explicitly named a model, use an effort-* carrier (e.g. subagent_type: \"effort-high\", model: \"$model\")." >&2
exit 2
