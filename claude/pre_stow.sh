#!/bin/bash
# Runs before `stow claude`, while ~/.local/scripts is still unstowed.
#
# standalone_quick_setup.sh installs plain copies of claude-wt/git-wt into
# ~/.local/scripts — the same directory this package stows into — and stow
# refuses to overwrite a real file it did not create. Remove identical copies;
# preserve different contents in a private backup directory before stowing.
set -eu

scripts_src="$(dirname "$0")/.local/scripts"
[ -d "$scripts_src" ] || exit 0

for src in "$scripts_src"/*; do
	[ -f "$src" ] || continue
	target="$HOME/.local/scripts/$(basename "$src")"
	if [ -f "$target" ] && [ ! -L "$target" ]; then
		if cmp -s "$src" "$target"; then
			rm "$target"
		else
			backup_root="$HOME/.local/state/dotfiles/backups"
			mkdir -p "$backup_root"
			backup_dir=$(mktemp -d "$backup_root/claude-scripts.XXXXXX")
			mv "$target" "$backup_dir/"
			echo "Preserved $target in $backup_dir"
		fi
	fi
done
