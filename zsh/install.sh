#!/bin/bash

MISSING=()
command -v bat &>/dev/null || MISSING+=(bat)
command -v eza &>/dev/null || MISSING+=(eza)
command -v fd &>/dev/null || MISSING+=(fd)
command -v fzf &>/dev/null || MISSING+=(fzf)
command -v jq &>/dev/null || MISSING+=(jq)
command -v rg &>/dev/null || MISSING+=(ripgrep)
command -v starship &>/dev/null || MISSING+=(starship)
command -v zoxide &>/dev/null || MISSING+=(zoxide)
[ ${#MISSING[@]} -gt 0 ] && brew install "${MISSING[@]}"

if command -v fzf &>/dev/null && [ ! -f ~/.fzf.zsh ]; then
	echo "Installing fzf key bindings and completion..."
	"$(brew --prefix fzf)"/install --key-bindings --completion --no-fish --no-update-rc
fi

if [ ! -d ~/.nvm ]; then
	echo "Installing nvm..."
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi

mkdir -p ~/.local/state/zsh
mkdir -p ~/.cache/zsh
