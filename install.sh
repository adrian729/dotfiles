#!/bin/bash

# Every path below is repo-relative, so anchor to the repo regardless of cwd.
# Resolve the root before cd'ing: $0 may itself be relative, in which case a
# second `dirname "$0"` after the cd would resolve against the wrong directory.
REPO_ROOT=$(cd "$(dirname "$0")" && pwd) || exit 1
cd "$REPO_ROOT" || exit 1

if [ ! -f "$REPO_ROOT/lib/common.sh" ]; then
	echo "install.sh: cannot find lib/common.sh next to this script." >&2
	echo "  Run it from a clone of the dotfiles repo (./install.sh), not through a symlink." >&2
	exit 1
fi
. "$REPO_ROOT/lib/common.sh"

# Bail before Homebrew or stow touch anything: an unattended run that cannot
# answer the per-package prompts should not first spend minutes installing a
# package manager it is about to abandon.
stow_all=""
for arg in "$@"; do
	case "$arg" in
	-y | --yes) stow_all="y" ;;
	esac
done

if [ -z "$stow_all" ] && [ ! -t 0 ]; then
	echo "install.sh: no controlling terminal and -y/--yes not given; refusing to run with unanswerable prompts." >&2
	exit 1
fi

brew_bootstrap || echo "⚠️  Continuing without Homebrew — most package installers will fail." >&2

# stow is the one hard requirement: without it nothing gets linked at all, so
# fall back to apt when the Homebrew bootstrap did not work out.
if ! command -v stow &>/dev/null; then
	ensure_cmd stow || apt_install stow ||
		{ echo "❌ stow is required and could not be installed." >&2; exit 1; }
fi

directories=(
  # AI tooling
  "opencode"
  "claude"
  "agents"
  "ollama"

  # Terminals
  "ghostty"
  "kitty"

  # Editor
  "nvim"
  "clangd"

  # Shell & multiplexer
  "tmux"
  "zsh"

  # Utilities
  "lf"
  "bettercmdtab"
)

# Packages with no Linux counterpart at all, filtered out before anything runs
# so they get no pre_stow.sh, no stow and no install.sh:
#   bettercmdtab — a macOS ⌘Tab replacement; there is no Linux equivalent.
#   kitty        — deliberate per-platform choice, not a packaging limit: on
#                  Linux the daily driver is ghostty alone. Drop kitty from
#                  this list if a Linux machine should get it too (kitty's own
#                  install.sh already refuses to run there, so change both).
macos_only=(
	"bettercmdtab"
	"kitty"
)

# Local, gitignored, per-machine opt-out: one package directory name per line,
# blank lines and #-comments ignored.
blacklist_file=".stow_blacklist.local"
blacklist=()

if [ -f "$blacklist_file" ]; then
	while IFS= read -r line; do
		line="${line%%#*}"
		line=$(echo "$line" | xargs)
		[ -n "$line" ] && blacklist+=("$line")
	done <"$blacklist_file"
fi

in_list() {
	local needle=$1 item
	shift
	for item in "$@"; do
		[ "$item" == "$needle" ] && return 0
	done
	return 1
}

# Report the platform reason ahead of the per-machine one: a package skipped
# because it cannot exist on this OS is not the same as one the user opted out
# of, and a package in both lists should only be announced once.
filtered=()
for dir in "${directories[@]}"; do
	if is_linux && in_list "$dir" "${macos_only[@]}"; then
		echo "🍎 Skipping $dir (macOS-only)."
	elif [ "${#blacklist[@]}" -gt 0 ] && in_list "$dir" "${blacklist[@]}"; then
		echo "🚫 Skipping $dir ($blacklist_file)."
	else
		filtered+=("$dir")
	fi
done
if [ "${#filtered[@]}" -ne "${#directories[@]}" ]; then
	directories=("${filtered[@]}")
	echo ""
fi

if [ -z "$stow_all" ]; then
	read -p "Do you want to stow all directories without asking? (y/n): " stow_all
fi
echo ""

# Stow a package, letting it clear its own way first: a package may ship a
# pre_stow.sh for anything that has to happen while the target files are still
# unstowed (stow refuses to overwrite a real file it didn't create).
stow_pkg() {
	local dir=$1
	echo "🔗 Stowing $dir..."
	if [ -f "$dir/pre_stow.sh" ]; then
		bash "$dir/pre_stow.sh" || echo "⚠️  $dir/pre_stow.sh failed — stowing anyway."
	fi
	# --no-folding is load-bearing, not a style choice. Without it stow "folds" a
	# whole directory into a single symlink whenever the target does not exist
	# yet — so on a fresh machine ~/.config becomes a link straight into this
	# repo. That exposes the three configs that are deliberately copied rather
	# than symlinked (claude's settings.json, opencode.json, bettercmdtab's
	# config.json): each tool then writes its state into the repo, dirtying it,
	# and their .stow-local-ignore entries do not help — ignoring a file stops
	# stow linking it individually, not the parent fold that exposes it anyway.
	if stow --no-folding -t "$HOME" "$dir"; then
		echo "✅ $dir stowed successfully!"
	else
		echo "❌ Failed to stow $dir (see warnings above)."
	fi
}

for dir in "${directories[@]}"; do
	if [ -d "$dir" ]; then
		if [[ "$stow_all" =~ ^[Yy]$ ]]; then
			stow_pkg "$dir"
		else
			read -p "Do you want to stow $dir? (y/n): " choice
			case "$choice" in
			y | Y)
				stow_pkg "$dir"
				;;
			*)
				echo "⏭️ Skipping $dir."
				;;
			esac
		fi
	else
		echo "☹️ Directory $dir does not exist."
	fi
	echo ""
done

echo "Running install scripts..."
for dir in "${directories[@]}"; do
	if [ -f "$dir/install.sh" ]; then
		echo "🔧 Running $dir/install.sh..."
		bash "$dir/install.sh"
		echo ""
	fi
done

echo ""
echo "🥳 Setup complete!"
