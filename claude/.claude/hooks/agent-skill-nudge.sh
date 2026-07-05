#!/usr/bin/env bash
# PreToolUse hook (matcher: Agent|Task): at the moment a subagent is spawned,
# remind the delegating assistant to check the task being handed off against
# skills' own "use when" guidance and embed matching rules in the subagent's
# prompt — subagents don't get the UserPromptSubmit skill nudge themselves.
# PreToolUse exit-0 plain stdout is transcript-only, NOT seen by the model —
# must emit hookSpecificOutput.additionalContext JSON to actually reach Claude.
# Debounced per session (best-effort; concurrent spawns can race past it,
# which just means an occasional redundant reminder, not a correctness bug).

command -v jq >/dev/null 2>&1 || exit 0  # fail open, never block spawns
input=$(cat)
session=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$session" ] && exit 0

state="${TMPDIR:-/tmp}/claude-agent-skill-nudge-${session}"
now=$(date +%s)
last=$(cat "$state" 2>/dev/null)
[[ "$last" =~ ^[0-9]+$ ]] || last=0   # corrupted/empty state file → treat as stale
[ $(( now - last )) -lt 5 ] && exit 0   # same batch of parallel spawns
echo "$now" > "$state"

source "$(dirname "$0")/lib/skill-names.sh"
names=$(skill_names "$(dirname "$0")/../skills")
[ -z "$names" ] && exit 0

context=$(cat <<EOF
Before this subagent starts: check the task you're delegating against these skills' own "use when" guidance, and if one genuinely applies, put its rules directly in the subagent's prompt — it won't get this check itself:
$names
EOF
)

jq -n --arg ctx "$context" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow", additionalContext: $ctx}}'
