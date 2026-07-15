#!/usr/bin/env bash
# Shared: print "    - <name>" for every installed skill. Sourced by
# skill-eval.sh and agent-skill-nudge.sh so the listing logic lives once.

# Manual-only skills: user-triggered explicitly, deliberately name-only in the
# harness listing — never nudge the model toward them.
MANUAL_ONLY=" audit-loop autonomous-process best-of-n evaluator-optimizer "

skill_names() {
    local dir="$1" name
    for f in "$dir"/*/SKILL.md; do
        [ -f "$f" ] || continue
        name=$(sed -n 's/^name: *//p' "$f" | head -1)
        [ -n "$name" ] || continue
        case "$MANUAL_ONLY" in *" $name "*) continue ;; esac
        printf '    - %s\n' "$name"
    done
}
