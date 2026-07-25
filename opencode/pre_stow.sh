#!/bin/bash
# Runs before `stow opencode`, while ~/.local/scripts is still unstowed.
#
# standalone_quick_setup.sh installs plain copies of the opencode-wt scripts
# into ~/.local/scripts — the same directory this package stows into — and stow
# refuses to overwrite a real file it did not create. Drop those copies so the
# repo version wins. Only regular files are removed; a symlink there is already
# stow's own work.

scripts_src="$(dirname "$0")/.local/scripts"
[ -d "$scripts_src" ] || exit 0

for src in "$scripts_src"/*; do
	[ -f "$src" ] || continue
	target="$HOME/.local/scripts/$(basename "$src")"
	if [ -f "$target" ] && [ ! -L "$target" ]; then
		echo "🧹 Removing standalone copy of $(basename "$src")"
		rm -f "$target"
	fi
done
