#!/usr/bin/env bash
# UserPromptSubmit: advise on delegation before the Agent call is composed.
AGENTS_DIR="$(dirname "$0")/../agents"
[ -d "$AGENTS_DIR" ] || exit 0

cat <<'EOF'
When delegating, select an agent that fits the task and preserve its pinned model; use an effort-* carrier for an explicitly requested model. Subagents do not inherit skills already invoked in this conversation: include necessary task-specific instructions or select an agent that preloads the relevant skill.
EOF
