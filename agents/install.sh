#!/bin/bash

. "$(dirname "$0")/../lib/common.sh"

# Strip AI attribution (co-author trailers, "Generated with" footers, session
# links) from every commit, whichever tool writes it. A config-defined hook
# (git 2.54+) runs alongside each repo's own hooks, unlike core.hooksPath, which
# would replace them. The one-liner fails open when the script or python3 is
# missing, and git appends the message path to its final command.
hook_cmd='f="$HOME/.local/scripts/ai-attribution-guard"; [ -x "$f" ] && command -v python3 >/dev/null 2>&1 || exit 0; exec "$f" commit-msg'
if ! have git; then
	warn "git not found — skipping the AI attribution commit-msg hook"
elif ! git config --global hook.ai-attribution-guard.command "$hook_cmd" ||
	! git config --global --replace-all hook.ai-attribution-guard.event commit-msg; then
	warn "failed to register the AI attribution commit-msg hook in the global git config"
else
	version=$(git --version | sed -E 's/[^0-9]*([0-9]+)\.([0-9]+).*/\1 \2/')
	read -r major minor <<<"$version"
	if [ "${major:-0}" -lt 2 ] || { [ "${major:-0}" -eq 2 ] && [ "${minor:-0}" -lt 54 ]; }; then
		warn "git $major.$minor ignores config-defined hooks (needs 2.54+) — AI attribution is not stripped from commits until git is upgraded"
	fi
fi
