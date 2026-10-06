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

# Stowed files that a tool replaced with a regular copy (`pnpm setup` rewrites
# .zshrc rather than appending through the link) or that predate the dotfiles.
# stow will not overwrite them, so the lines a copy adds move to the profile and
# the copy to a backup. Only zsh code can move there; any other changed file
# (starship.toml) is left for the user. Startup files first, in zsh's load order,
# so the profile keeps it.
config_dir="$HOME/.config/zsh"
repo_config="$pkg_dir/.config/zsh"
strays=()
blocked=()
for repo_file in "$repo_config"/.zshenv "$repo_config"/.zprofile "$repo_config"/.zshrc \
	"$repo_config"/.zlogin "$repo_config"/.zlogout "$repo_config"/*; do
	[ -f "$repo_file" ] || continue
	name=${repo_file##*/}
	live="$config_dir/$name"
	[ -f "$live" ] && [ ! -L "$live" ] || continue
	# A fold left by an older install makes ~/.config/zsh a link into this repo,
	# so its files are the repo's own: never move them.
	[ "$live" -ef "$repo_file" ] && continue
	case "$name" in
	.z* | *.zsh) strays+=("$name") ;;
	*) if cmp -s "$live" "$repo_file"; then strays+=("$name"); else blocked+=("$live"); fi ;;
	esac
done
if [ ${#blocked[@]} -gt 0 ]; then
	for live in "${blocked[@]}"; do
		echo "❌ $live is a regular file that differs from the repo version, so stow cannot" \
			"link it; merge what you need into the repo, then remove it." >&2
	done
	exit 1
fi

stray_dir=""
if [ ${#strays[@]} -gt 0 ]; then
	mkdir -p "$backup_root"
	stray_dir=$(mktemp -d "$backup_root/config-zsh.XXXXXX")
	for name in "${strays[@]}"; do mv "$config_dir/$name" "$stray_dir/"; done
fi

target="$HOME/.zshenv"
backup_dir=""
if [ -f "$target" ] && [ ! -L "$target" ]; then
	mkdir -p "$backup_root"
	backup_dir=$(mktemp -d "$backup_root/zshenv.XXXXXX")
	mv "$target" "$backup_dir/"
fi

# Moving files first is the only way to ask stow whether anything else is in
# the way. If something is, put them all back: the stow that follows would fail
# and leave the shell without the user's ZDOTDIR setup or its startup files.
if { [ -n "$backup_dir" ] || [ -n "$stray_dir" ]; } && command -v stow >/dev/null 2>&1 &&
	! conflicts=$(stow -n --no-folding -R -d "$(dirname "$pkg_dir")" -t "$HOME" \
		"$(basename "$pkg_dir")" 2>&1); then
	if [ -n "$backup_dir" ]; then
		mv "$backup_dir/.zshenv" "$target"
		rmdir "$backup_dir"
	fi
	if [ -n "$stray_dir" ]; then
		for name in "${strays[@]}"; do mv "$stray_dir/$name" "$config_dir/"; done
		rmdir "$stray_dir"
	fi
	printf '%s\n' "$conflicts" >&2
	echo "❌ Other files block stowing zsh; left $target and $config_dir in place." >&2
	exit 1
fi

# zsh's own load order, so later files still override earlier ones.
migrate "$target" "${backup_dir:+$backup_dir/.zshenv}"
migrate "$HOME/.zprofile"
migrate "$HOME/.zshrc"

# carry NAME — append to the profile the lines that the backed-up copy of
# ~/.config/zsh/NAME adds. The base is the committed version of NAME closest to
# the copy, not the current one: a copy taken before repo changes that have
# since been pulled would otherwise carry the old lines back as local ones.
carry() {
	local name=$1 copy="$stray_dir/$1" base cand rev n best added dropped
	base=$(mktemp)
	cand=$(mktemp)
	cp "$repo_config/$name" "$base"
	best=$(diff "$base" "$copy" | grep -c '^[<>]' || true)
	if [ "$best" -gt 0 ] && git -C "$pkg_dir" rev-parse --git-dir >/dev/null 2>&1; then
		for rev in $(git -C "$pkg_dir" log --format=%H -n 50 -- ".config/zsh/$name"); do
			git -C "$pkg_dir" show "$rev:./.config/zsh/$name" >"$cand" 2>/dev/null || continue
			n=$(diff "$cand" "$copy" | grep -c '^[<>]' || true)
			if [ "$n" -lt "$best" ]; then
				best=$n
				cp "$cand" "$base"
			fi
		done
	fi
	added=$(diff "$base" "$copy" | sed -n 's/^> \{0,1\}//p' |
		sed -E "\\@$recursive@s@^@# disabled by zsh/pre_stow.sh, would recurse: @")
	dropped=$(diff "$base" "$copy" | grep -c '^<' || true)
	rm -f "$base" "$cand"
	if [ "$best" -eq 0 ]; then
		rm -f "$copy"
		return 0
	fi
	# A tool that keeps rewriting the file (pnpm setup again) adds the same block.
	if [ -n "$added" ] && [[ "$(cat "$profile" 2>/dev/null)" != *"$added"* ]]; then
		mkdir -p "$(dirname "$profile")"
		{
			printf '\n# >>> moved from %s by dotfiles zsh/pre_stow.sh\n' "$config_dir/$name"
			printf '%s\n' "$added"
			printf '# <<< end of %s\n' "$config_dir/$name"
		} >>"$profile"
		echo "Moved the lines $config_dir/$name added into $profile; the copy is in $stray_dir."
		case "$name" in
		.zshenv | .zprofile) echo "  They now run in interactive shells only, after the dotfiles .zshrc." ;;
		esac
	fi
	if [ "$dropped" -gt 0 ]; then
		echo "⚠️  $config_dir/$name also lacked $dropped line(s) of the repo version;" \
			"compare it with the copy in $stray_dir." >&2
	fi
}
if [ -n "$stray_dir" ]; then
	for name in "${strays[@]}"; do carry "$name"; done
	rmdir "$stray_dir" 2>/dev/null || true
fi

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
