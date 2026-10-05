#!/bin/bash
# Runs before `stow zsh`, while ~/.zshenv may still be a pre-dotfiles file.
#
# The stowed ~/.zshenv points ZDOTDIR at ~/.config/zsh, after which zsh never
# reads ~/.zshrc or ~/.zprofile again, and stow refuses to replace a real
# ~/.zshenv it did not create. So that PATH entries and tool hooks added by
# other installers (pnpm, OrbStack, direnv, ...) keep working, copy each
# legacy file once into ~/.local/.local_profile, which the dotfiles .zshrc
# sources last. ~/.zshrc and ~/.zprofile stay in place untouched; ~/.zshenv
# moves to a private backup directory so stow can link it.
set -eu

pkg_dir="$(cd "$(dirname "$0")" && pwd)"
repo_zshenv="$pkg_dir/.zshenv"
profile="$HOME/.local/.local_profile"
state_dir="$HOME/.local/state/dotfiles"
# Which files were copied, kept outside the profile so that pruning the copy
# there does not bring it back on the next install.
migrated_list="$state_dir/zsh-migrated"
backup_root="$state_dir/backups"

# A symlink is managed by something else (or is this package's own link), and
# an identical copy of the repo file has nothing local to carry over.
is_legacy() {
	[ -f "$1" ] && [ ! -L "$1" ] && [ -s "$1" ] && ! cmp -s "$1" "$repo_zshenv"
}

# A line sourcing the profile itself, or a .zshrc (which sources the profile),
# would recurse once it runs from inside the profile: an older copy of this
# repo's .zshrc carries exactly that line.
recursive='^[^#]*(source|\.)[[:space:]][^#]*(\.local_profile|/\.zshrc)["'\'']?([[:space:];&|)]|$)'

# migrate NAME [FILE] — append FILE (default NAME) to the profile under NAME,
# unless NAME was copied before. Profiles written before the list existed are
# recognised by their marker line.
migrate() {
	local name=$1 file=${2:-$1} begin
	is_legacy "$file" || return 0
	grep -qxF "$name" "$migrated_list" 2>/dev/null && return 0
	begin="# >>> migrated from $name by dotfiles zsh/pre_stow.sh"
	if ! grep -qxF "$begin" "$profile" 2>/dev/null; then
		mkdir -p "$(dirname "$profile")"
		{
			printf '\n%s\n' "$begin"
			sed -E "\\@$recursive@s@^@# disabled by zsh/pre_stow.sh, would recurse: @" "$file"
			printf '\n# <<< end of %s\n' "$name"
		} >>"$profile"
		echo "Copied $name into $profile — prune anything the dotfiles already provide."
		echo "  It now runs in interactive shells only, after the dotfiles .zshrc."
	fi
	mkdir -p "$state_dir"
	echo "$name" >>"$migrated_list"
}

target="$HOME/.zshenv"
backup_dir=""
if [ -f "$target" ] && [ ! -L "$target" ]; then
	mkdir -p "$backup_root"
	backup_dir=$(mktemp -d "$backup_root/zshenv.XXXXXX")
	mv "$target" "$backup_dir/"
	# Moving it first is the only way to ask stow whether anything else is in
	# the way. If something is, put it back: the stow that follows would fail
	# and leave the shell without the user's ZDOTDIR setup.
	if command -v stow >/dev/null 2>&1 &&
		! conflicts=$(stow -n --no-folding -R -d "$(dirname "$pkg_dir")" -t "$HOME" \
			"$(basename "$pkg_dir")" 2>&1); then
		mv "$backup_dir/.zshenv" "$target"
		rmdir "$backup_dir"
		printf '%s\n' "$conflicts" >&2
		echo "❌ Other files block stowing zsh; left $target in place." >&2
		exit 1
	fi
fi

# zsh's own load order, so later files still override earlier ones.
migrate "$target" "${backup_dir:+$backup_dir/.zshenv}"
migrate "$HOME/.zprofile"
migrate "$HOME/.zshrc"

# A link into the ZDOTDIR files themselves is a convenience, not config to lose.
for file in "$HOME/.zprofile" "$HOME/.zshrc"; do
	[ -L "$file" ] || continue
	case "$(readlink "$file")" in */.config/zsh/.z*) continue ;; esac
	echo "⚠️  $file links to $(readlink "$file"), which zsh stops reading once" \
		"ZDOTDIR is set; source it from $profile if it is still needed." >&2
done

if [ -n "$backup_dir" ]; then
	if cmp -s "$backup_dir/.zshenv" "$repo_zshenv"; then
		rm -rf "$backup_dir"
	else
		echo "Moved $target to $backup_dir"
	fi
fi
