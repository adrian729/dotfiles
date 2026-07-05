#!/usr/bin/env bash
# UserPromptSubmit hook: nudge the model to evaluate available skills each turn.
# Lists skill NAMES only — the harness already injects full descriptions into
# context, so re-printing them would just duplicate tokens. Fires every prompt
# (no session gating) because skill relevance often emerges mid-session.

SKILLS_DIR="$(dirname "$0")/../skills"

source "$(dirname "$0")/lib/skill-names.sh"
names=$(skill_names "$SKILLS_DIR")

# Nothing to evaluate (skills dir missing/empty) — exit quietly.
[ -z "$names" ] && exit 0

cat <<EOF
Before responding, check whether any of these skills applies to the request —
honoring each skill's own "use when / do NOT trigger" guidance — and call
Skill() for any genuine match:
$names
EOF
