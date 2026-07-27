#!/bin/bash

if ! command -v brew &>/dev/null; then
	echo "Installing Homebrew..."
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	if [ -f /opt/homebrew/bin/brew ]; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
	elif [ -f /usr/local/bin/brew ]; then
		eval "$(/usr/local/bin/brew shellenv)"
	elif [ -f /home/linuxbrew/.linuxbrew/bin/brew ]; then
		eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
	fi
fi

if ! command -v stow &>/dev/null; then
	brew install stow
fi

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

is_blacklisted() {
	local needle=$1
	for item in "${blacklist[@]}"; do
		[ "$item" == "$needle" ] && return 0
	done
	return 1
}

if [ "${#blacklist[@]}" -gt 0 ]; then
	filtered=()
	for dir in "${directories[@]}"; do
		if is_blacklisted "$dir"; then
			echo "🚫 Skipping $dir ($blacklist_file)."
		else
			filtered+=("$dir")
		fi
	done
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
	if stow -t "$HOME" "$dir"; then
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
