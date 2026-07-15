#!/bin/bash

if ! command -v brew &>/dev/null; then
	echo "Installing Homebrew..."
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	if [ -f /opt/homebrew/bin/brew ]; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
	elif [ -f /usr/local/bin/brew ]; then
		eval "$(/usr/local/bin/brew shellenv)"
	fi
fi

if ! command -v stow &>/dev/null; then
	brew install stow
fi

directories=(
  # AI tooling
  "opencode"
  "claude"
  "agents"
  "ollama"

  # Terminals
  "ghostty"

  # Editor
  "nvim"
  "clangd"

  # Shell & multiplexer
  "tmux"
  "zsh"

  # Utilities
  "lf"
)

read -p "Do you want to stow all directories without asking? (y/n): " stow_all
echo ""

for dir in "${directories[@]}"; do
	if [ -d "$dir" ]; then
		if [[ "$stow_all" =~ ^[Yy]$ ]]; then
			echo "🔗 Stowing $dir..."
			if stow "$dir"; then
				echo "✅ $dir stowed successfully!"
			else
				echo "❌ Failed to stow $dir (see warnings above)."
			fi
		else
			read -p "Do you want to stow $dir? (y/n): " choice
			case "$choice" in
			y | Y)
				echo "🔗 Stowing $dir..."
				if stow "$dir"; then
					echo "✅ $dir stowed successfully!"
				else
					echo "❌ Failed to stow $dir (see warnings above)."
				fi
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
