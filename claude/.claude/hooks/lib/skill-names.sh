#!/usr/bin/env bash
# Shared: print "    - <name>" for every installed skill. Sourced by
# skill-eval.sh and agent-skill-nudge.sh so the listing logic lives once.
skill_names() {
    local dir="$1" name
    for f in "$dir"/*/SKILL.md; do
        [ -f "$f" ] || continue
        name=$(sed -n 's/^name: *//p' "$f" | head -1)
        [ -n "$name" ] && printf '    - %s\n' "$name"
    done
}
