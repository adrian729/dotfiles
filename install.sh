#!/bin/bash

if ! command -v stow &>/dev/null; then
	echo "GNU Stow could not be found, please install it first."
	exit
fi

directories=(
  "opencode"
  "claude"
  "agents"
  "kitty"
  "ghostty"
  "nvim"
  "clangd"
  "tmux"
  "zsh"
  "ollama"
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
